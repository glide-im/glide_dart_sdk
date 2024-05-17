import 'dart:async';
import 'dart:io';

import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:rxdart/rxdart.dart';

import 'message_task.dart';
import 'ws_conn.dart';

typedef WsClientStateListener = void Function(WsClientState state);

typedef Authenticator = Future<dynamic> Function(WsClient client);

typedef ConnectFn = Future<dynamic> Function(WsConnection client);

typedef Heartbeat = Future<dynamic> Function(WsClient client);

///  对 websocket 重连, 认证, 协议交互层封装.
abstract class WsClient {
  /// 创建一个 ws 客户端
  factory WsClient.create() {
    WsConnection conn = WsConnection();
    return WsClientImpl(conn);
  }

  /// 通过 [WsConnect] 创建 [WsClient] 实例
  factory WsClient.createWithConnection(WsConnection conn) {
    return WsClientImpl(conn);
  }

  /// 登录成功后需要调用此方法, 否则发送需要认证的消息将会调用自动认证方法 [authFn]
  /// 但此方法一般不作为首次连接的认证方法, 而是连接断开使用令牌登录等临时方法.
  void setAuthenticationCompleted();

  /// 设置是否自动重连
  /// [autoReconnect] 是否在断开连接后自动重连
  /// [delay] 重连的延迟间隔
  void setAutoReconnect(bool autoReconnect, {Duration? delay});

  /// 设置重连后登录的方法, 当需要认证时, 例如 socket connection 触发 close 事件重连后, 或发送需要认证的消息而当前状态为为认证时.
  /// 当 websocket 重连需要认证时, 会调用 [authFn], 需要在 [authFn] 中处理登录逻辑.
  void setAuthFunc(Authenticator? authFn);

  /// 设置当断开后重连的方法
  /// 当 websocket 断开并需要重连时, 会调用 [connectFn], 可以在回调返回的 [Future] 中定义如何重连, 例如切换服务器, 延迟等待重连等.
  void setConnectFunc(ConnectFn connectFn);

  /// 订阅 ws 客户端状态变化
  StreamSubscription<dynamic> subscriptionState(WsClientStateListener listener);

  /// 订阅消息
  StreamSubscription<dynamic> subscribeMessage(
      Function(dynamic message) listener);

  WsClientState currentState();

  /// 立即关闭连接, 所有发送中的消息将无法收到成功结果
  ///
  /// [discardMessages] 丢弃发送中的消息以及等待结果的消息
  /// [reconnect] 是否在关闭后重新连接
  Future close({bool discardMessages = false, bool reconnect = false});

  /// 连接 websocket, 若已连接将不会有操作.
  ///
  /// [authNeeded] 连接成功后是否立即认证
  /// [url] 连接的 url, 若未指定, 则使用 ReconnectFn 方法重连
  Future connect({bool authNeeded = false, String? url});

  /// 创建一个消息发送任务 [MessageTask].
  MessageTask<T> send<T>(dynamic msg,
      {serializeToJson = true,
      bool awaitConnect = false,
      bool needAuth = false});
}

/// WebSocket 客户端状态
enum WsClientState {
  known,
  // 连接已断开
  disconnected,
  // 连接中
  connecting,
  // 连接已建立
  connected,
  // 关闭中
  closing;

  factory WsClientState.fromWebsocketState(int websocketState) {
    switch (websocketState) {
      case WebSocket.closed:
        return WsClientState.disconnected;
      case WebSocket.closing:
        return WsClientState.closing;
      case WebSocket.connecting:
        return WsClientState.connecting;
      case WebSocket.open:
        return WsClientState.connected;
      default:
        return WsClientState.known;
    }
  }
}

class WsClientImpl implements WsClient {
  static const String _tag = "_WsClientImpl";

  final WsConnection _wsConnection;
  Future Function(WsClient client)? _authFn;
  Future Function(WsConnection client) _reconnectFn =
      (WsConnection c) => c.connect();

  final StreamController<dynamic> _msgSc = StreamController.broadcast();
  final StreamController<WsClientState> _stateSc = StreamController.broadcast();

  bool _autoReconnect = true;
  bool _authed = false;
  WsClientState _state = WsClientState.disconnected;
  Duration _autoConnectDelay = const Duration(seconds: 3);

  WsClientImpl(this._wsConnection, [autoReconnect = true]) {
    _autoReconnect = autoReconnect;
    _wsConnection.addMessageListener((message) {
      _msgSc.add(message);
    });
    _wsConnection.stateStream().listen((event) {
      _authed = false;
      final s = WsClientState.fromWebsocketState(event);
      _stateChange(s);
      if (s == WsClientState.disconnected) {
        if (_autoReconnect) {
          Future.delayed(_autoConnectDelay, () {
            _tryConnect(true, isAutoConnect: true);
          });
        }
      }
    }, onError: (error) {
      Logger.err(_tag, "stateStream error: $error");
    });
  }

  @override
  void setAuthenticationCompleted() {
    _authed = true;
  }

  @override
  void setAutoReconnect(bool autoReconnect, {Duration? delay}) {
    _autoReconnect = autoReconnect;
    if (delay != null) {
      _autoConnectDelay = delay;
    }
  }

  @override
  void setConnectFunc(Future Function(WsConnection client) reconnectFn) {
    _reconnectFn = reconnectFn;
  }

  @override
  void setAuthFunc(Future<dynamic> Function(WsClient c)? authFn) {
    _authFn = authFn;
  }

  @override
  Future close({bool discardMessages = false, bool reconnect = false}) async {
    /// 临时设置全局重连
    final t = _autoReconnect;
    _autoReconnect = reconnect;
    try {
      _wsConnection.close();
      await _stateSc.stream
          .firstWhere((element) => element == WsClientState.disconnected);
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      Logger.err(_tag, e);
    }
    _autoReconnect = t;
  }

  @override
  Future connect({authNeeded = false, String? url}) async {
    await _tryConnect(authNeeded, url: url);
  }

  @override
  StreamSubscription subscribeMessage(Function(String message) listener) {
    return _msgSc.stream.listen((m) {
      try {
        listener(m);
      } catch (e) {
        Logger.err(_tag, "message listener error: $e");
      }
    });
  }

  @override
  WsClientState currentState() {
    return _state;
  }

  @override
  StreamSubscription subscriptionState(Function(WsClientState state) f) {
    return _stateSc.stream.listen((event) {
      try {
        f(event);
      } catch (e) {
        Logger.err(_tag, "state listener error: $e");
      }
    });
  }

  @override
  MessageTask<T> send<T>(
    dynamic msg, {
    serializeToJson = true,
    bool awaitConnect = false,
    bool needAuth = false,
  }) {
    MessageTask<T> task = MessageTask();
    task.addStep((_) => _whenAvailable(awaitConnect, needAuth));
    task.addStep((_) => _wsConnection.send(msg, serializeToJson));
    return task;
  }

  /// 如果当前已连接, 则直接回调 Future, 否则等待连接成功并登录后返回.
  ///
  /// [authentication] 是否需要等待认证
  Future<void> _waitForAvailable(bool authentication) {
    if (_state == WsClientState.connected) {
      if (!_authed && authentication) {
        return _authentication();
      } else {
        return Future.value();
      }
    }
    _tryConnect(authentication, isAutoConnect: true);
    Logger.debug(_tag, "waiting for ws available...");

    // 每秒检测一次连接状态
    return Stream.periodic(const Duration(seconds: 1), (i) {
      return _state == WsClientState.connected &&
          (!authentication || (authentication && _authed));
    }).firstWhere((opened) => opened).then((value) {
      Logger.debug(_tag, "ws available");
    });
  }

  /// 尝试连接到服务器
  Future _tryConnect(bool authNeeded,
      {String? url, bool isAutoConnect = false}) {
    if (!_autoReconnect && isAutoConnect) {
      return Future.value();
    }

    if (_state != WsClientState.disconnected) {
      Logger.info(_tag, 'skip connect: $_state');
      return Future.value();
    }
    return Future(() async {
      if (_state == WsClientState.connecting) {
        Logger.info(_tag, 'skip connect: $_state');
        return;
      }
      _stateChange(WsClientState.connecting);
      int retry = 0;
      await RetryWhenStream(() {
        Logger.debug(
            _tag,
            retry++ > 0
                ? "try reconnecting $retry times..."
                : "connecting to ws server...");

        if (url != null) {
          return _wsConnection.connect(url).asStream();
        } else {
          final cs = _reconnectFn(_wsConnection);
          return cs.asStream();
        }
      }, (
        Object error,
        StackTrace stackTrace,
      ) {
        // 网络异常不重试
        if (error is SocketException) {
          Logger.debug(_tag,
              "stop retry connect, code: ${error.osError?.errorCode}, msg: ${error.osError?.message}");
          throw error;
        } else {
          Logger.debug(_tag, "connect failed:$_state, $error");
        }
        // 重试 10 次
        if (retry > 10) {
          throw error;
        }
        // 失败间隔 1 秒
        return Rx.timer(null, const Duration(seconds: 1));
      }).first;
    }).then((_) {
      if (authNeeded) {
        _authentication();
      }
    }).catchError((e) {
      Logger.debug(_tag, "reconnect error: $e");
      _stateChange(WsClientState.disconnected);
    });
  }

  /// 开始 websocket 鉴权
  Future _authentication() async {
    if (_authFn == null || _authed) {
      Logger.debug(
          _tag, "authentication skipped, authFunc: $_authFn, authed: $_authed");
      return;
    }
    Logger.debug(_tag, "authentication ...");
    await _authFn!(this).then((value) {
      _authed = true;
      Logger.debug(_tag, "authentication success");
    }).catchError((e) {
      Logger.debug(_tag, "authentication failed: $e");
      close(discardMessages: true);
    });
  }

  /// 更新 WsClient 当前状态, 发布状态更新事件
  void _stateChange(WsClientState state) {
    _state = state;
    // 发布状态变化事件
    _stateSc.add(state);
  }

  Future _whenAvailable(bool needConnect, bool needAuth, [int timeout = 3600]) {
    if (needConnect) {
      return _waitForAvailable(needAuth).timeout(Duration(seconds: timeout));
    }
    return Future.value();
  }
}
