import 'dart:async';
import 'dart:io';

import 'package:glide_dart_sdk/src/api/apis.dart';
import 'package:glide_dart_sdk/src/api/bean/auth_bean.dart';
import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:glide_dart_sdk/src/context.dart';
import 'package:glide_dart_sdk/src/errors.dart';
import 'package:glide_dart_sdk/src/session.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/ws_client.dart';
import 'package:glide_dart_sdk/src/ws/ws_conn.dart';
import 'package:rxdart/rxdart.dart';

import 'config.dart';
import 'message.dart';
import 'session_manager.dart';
import 'ws/messages.dart';
import 'ws/protocol.dart';
import 'ws/ws_im_client.dart';

enum GlideState {
  init,
  disconnected,
  connected,
  connecting;
}

class Glide {
  final tag = "Glide";
  final _cli = GlideWsClient();
  String _token = "";
  late Context _context;
  late SessionManagerInternal _sessions;
  final _interceptor = DefaultSessionEventInterceptor();

  final StreamController<GlideState> _stateSc = StreamController.broadcast();
  final GlideApi api = GlideApi();

  GlideState state = GlideState.init;

  Glide() {
    _context = Context(
      api: api,
      ws: _cli,
      sessionCache: SessionListMemoryCache(),
      messageCache: GlideMessageMemoryCache(),
      myId: "",
      sessionEventInterceptor: _interceptor,
    );
    _sessions = SessionManagerInternal(_context);
  }

  void setSessionCache(SessionListCache c) {
    _context.sessionCache = c;
  }

  void setMessageCache(GlideMessageCache c) {
    _context.messageCache = c;
  }

  void setSessionEventInterceptor(SessionEventInterceptor interceptor) {
    _interceptor.wrap = interceptor;
  }

  String? uid() => _context.myId;

  Stream<String> init() async* {
    yield "$tag start init";
    states().listen((event) {
      state = event;
    });

    Http.init(Configs.apiBaseUrl);
    _cli.setConnectFunc(_connectFn);
    _cli.setAuthFunc(_authenticationFn);
    _cli.subscriptionState((state) {
      Logger.info(tag, "ws client state changed: $state");
      switch (state) {
        case WsClientState.known:
          break;
        case WsClientState.disconnected:
          _stateSc.add(GlideState.disconnected);
          break;
        case WsClientState.connecting:
          _stateSc.add(GlideState.connecting);
          break;
        case WsClientState.connected:
          break;
        case WsClientState.closing:
          break;
      }
    });
    _cli.messageStream().listen(
      (event) {
        _handleMessage(event);
      },
      onError: (e) {},
      onDone: () {},
    );

    yield "$tag init done";
  }

  Stream<GlideState> states() => _stateSc.stream;

  Stream<Message> messageStream() => _context.event.stream.mapNotNull((event) {
        return event.event is Message ? event.event : null;
      });

  SessionManager get sessionManager => _sessions;

  Future logout() async {
    _context.myId = "";
    await _sessions.clear();
    if (state == GlideState.connected) {
      await _cli.close(discardMessages: true);
    }
  }

  static void setLogger(IOSink? sink) {
    Logger.setSink(sink);
  }

  Future<AuthBean> tokenLogin(String token) async {
    return await api.auth.loginToken(token);
  }

  Future<AuthBean> guestLogin(String nickname, String avatar) async {
    return await api.auth.loginGuest(nickname, avatar);
  }

  Future<AuthBean> login(String account, String password) async {
    return await api.auth.loginPassword(account, password);
  }

  Future connect(AuthBean bean) async {
    _context.myId = bean.uid!.toString();
    _token = bean.token!;
    final credential = bean.credential!.toJson();
    Http.setToken(bean.token!);

    Logger.info(tag, "websocket authentication...");
    await _cli.request(Action.auth, credential, needAuth: false);
    _stateSc.add(GlideState.connected);
    _cli.setAuthenticationCompleted();
    Logger.info(tag, "websocket authenticated");
  }

  Future initCache(String uid) async {
    Logger.info(tag,
        "init account cache, uid: $uid, ${_context.sessionCache}, ${_context.messageCache}");
    await _context.sessionCache
        .init(uid)
        .timeout(const Duration(seconds: 5));
    await _context.messageCache
        .init(uid)
        .timeout(const Duration(seconds: 5));

    await _sessions.init().forEach((event) {
      Logger.info(tag, "session manager: $event");
    }).timeout(const Duration(seconds: 5));
    Logger.info(tag, "init cache done");
  }

  Future _connectFn(WsConnection client) async {
    await client.connect(Configs.wsUrl);
  }

  Future _authenticationFn(GlideWsClient client) async {
    if (_token.isEmpty) {
      client.close();
      throw GlideException.unauthorized;
    }
    try {
      final bean = await api.auth.loginToken(_token);
      await client.request(Action.auth, bean.credential!.toJson(),
          needAuth: false);
    } catch (e) {
      client.close();
      throw GlideException.authorizeFailed;
    }
    _stateSc.add(GlideState.connected);
    client.setAuthenticationCompleted();
  }

  void _handleMessage(ProtocolMessage message) {
    switch (message.action) {
      case Action.messageChat:
      case Action.messageGroup:
      case Action.messageGroupNotify:
        Message cm = Message.fromMap(message.data);
        _sessions
            .onMessage(message.action, cm)
            .timeout(const Duration(seconds: 3))
            .listen(
          (event) {
            Logger.info(tag, "[message-${message.hashCode}] $event");
          },
          onError: (e) {
            Logger.err(tag, e);
          },
          onDone: () {
            Logger.info(tag, "[message-${message.hashCode}] handled done");
          },
        );
        break;
      case Action.messageClient:
        Message cm = Message.fromMap(message.data);
        _sessions
            .onClientMessage(message.action, cm)
            .timeout(const Duration(seconds: 3))
            .listen(
          (event) {
            Logger.info(tag, "[cli-message-${message.hashCode}] $event");
          },
          onError: (e) {
            Logger.err(tag, e);
          },
        );
        break;
      case Action.ackNotify:
      case Action.ackMessage:
        final ack = GlideAckMessage.fromMap(message.data);
        _sessions
            .onAck(message.action, ack)
            .timeout(const Duration(seconds: 3))
            .listen((event) {
          //
        }, onError: (e, s) {
          Logger.err(tag, s);
        });
        break;
      case Action.kickout:
        logout().ignore();
        break;
      default:
        break;
    }
  }
}
