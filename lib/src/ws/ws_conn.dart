import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_web.dart' if (dart.library.io) 'websocket_io.dart';

typedef Disposable = void Function();

typedef StateListener = void Function(int state, String msg);

abstract class WsConnection {
  factory WsConnection() {
    return _Ws();
  }

  /// [Websocket.connecting], [Websocket.open], [Websocket.closing], [Websocket.closed]
  int currentState = 0;

  /// 返回 ws 断开的 reason
  String getReason();

  Stream<dynamic>? getStream();

  /// 连接 ws, 若设置 url, 则覆盖之前的 url, 否则使用上一次连接的 url.
  Future<WsConnection> connect([String? url, Duration timeout = const Duration(seconds: 10)]);

  Future<dynamic> close();

  /// 发送消息
  ///
  /// [message] 消息对象
  /// [jsonSerializable] 是否可序列化 json 对象, true 将发送前序列化为字符串
  Future<void> send(dynamic message, [bool jsonSerializable = true]);

  Stream<int> stateStream();

  Disposable addMessageListener(void Function(dynamic message) listener);
}

class WsException implements Exception {
  static const int codeClosed = 1;
  static const int codeTimeout = 2;
  static const int codeError = 3;
  static const int codeUnknown = 4;
  static const int codeNotConnectedYet = 5;

  final String message;
  final int code;

  WsException(this.code, this.message);

  @override
  String toString() {
    return 'WsException{message: $message, code: $code}';
  }
}

class _Ws implements WsConnection {
  static const _tag = "Ws";

  late WebSocketChannel _ws;
  String _url = "";
  bool _initialized = false;
  final JsonEncoder _jsonEncoder = const JsonEncoder();
  final StreamController<dynamic> _msgSc = StreamController.broadcast();
  final StreamController<int> _stateSc = StreamController.broadcast();

  @override
  int currentState = WebSocket.connecting;

  _Ws() {
    _stateSc.stream.listen((event) {
      currentState = event;
    });
  }

  @override
  String getReason() {
    if (!_initialized) {
      return "";
    }
    return _ws.closeReason ?? "";
  }

  @override
  Stream? getStream() {
    if (!_initialized) {
      return null;
    }
    return _msgSc.stream;
  }

  @override
  Future<WsConnection> connect([String? url, Duration timeout = const Duration(seconds: 10)]) async {
    final closed = currentState == WebSocket.closed;
    final connecting = currentState == WebSocket.connecting;

    if (_initialized && (!closed || connecting)) {
      throw WsException(WsException.codeError, "ws is not closed");
    }
    if (url?.trim().isEmpty ?? false) {
      throw WsException(WsException.codeError, "url is empty");
    }
    if (url != null && url.isNotEmpty) {
      _url = url.trim();
    }
    _newState(WebSocket.connecting);
    Logger.debug(_tag, "connecting to $_url");

    try {
      _ws = WebSocketFactory.create(_url);
      _ws.stream.listen(_onMessage, onError: _onError, onDone: _onDone);
      await _ws.ready.timeout(timeout);
      Logger.debug(_tag, "ws connected");
      _initialized = true;
      _newState(WebSocket.open);
    } catch (e) {
      currentState = WebSocket.closed;
      rethrow;
    }
    return this;
  }

  @override
  Future<void> send(dynamic message, [bool json = true]) async {
    if (!_initialized) {
      throw WsException(WsException.codeNotConnectedYet, "connection not initialized");
    }
    if (currentState != WebSocket.open) {
      throw WsException(WsException.codeClosed, "ws is not open, current state: $currentState");
    }
    try {
      var m = message;
      if (json) {
        m = _jsonEncoder.convert(message);
      }
      Logger.debug(_tag, "[send]\t$m");
      _ws.sink.add(m);
    } catch (e) {
      throw WsException(WsException.codeUnknown, "send failed due to: $e");
    }
    return message;
  }

  @override
  Future<dynamic> close() async {
    if (!_initialized) {
      throw WsException(WsException.codeNotConnectedYet, "connection not initialized");
    }
    Logger.debug(_tag, "closing...");
    _newState(WebSocket.closing);
    await _ws.sink.close(null, "close by client");
    _newState(WebSocket.closed);
  }

  @override
  Stream<int> stateStream() {
    return _stateSc.stream;
  }

  @override
  Disposable addMessageListener(void Function(dynamic message) listener) {
    var dispose = _msgSc.stream.listen((event) {
      listener(event);
    });
    return () {
      dispose.cancel();
    };
  }

  void _onError(dynamic error) {
    Logger.err(_tag, "on error $error");
    if (_ws.closeCode != null) {
      _newState(WebSocket.closed);
    }
    _msgSc.addError(error);
  }

  void _onDone() {
    // FIXME 2022年8月4日18:51:12 onDone 调用时机未知, closeCode 为 null
    Logger.debug(_tag, "ws closed: ${_ws.closeCode} ${_ws.closeReason}");
    _newState(WebSocket.closed);
  }

  void _onMessage(dynamic message) {
    Logger.debug(_tag, "[recv]\t$message");
    _msgSc.add(message);
  }

  void _newState(int newState) {
    currentState = newState;
    // if (currentState != newState) {
    _stateSc.add(newState);
    // }
  }
}
