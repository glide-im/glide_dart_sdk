import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../utils/logger.dart';

typedef Disposable = void Function();

typedef StateListener = void Function(int state, String msg);

abstract class WsConnection {
  factory WsConnection(String url) {
    return _Ws(url);
  }

  int getState();

  String getReason();

  Stream<dynamic>? getStream();

  Future<WsConnection> connect();

  Future<dynamic> close();

  Future<void> send(dynamic message);

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

  final JsonEncoder _jsonEncoder = const JsonEncoder();
  final String _url;
  late StreamController<dynamic> _msgSc;
  late IOWebSocketChannel _ws;
  bool _initialized = false;
  final StreamController<int> _stateSc;

  _Ws(this._url) : _stateSc = StreamController.broadcast() {
    _msgSc = StreamController.broadcast();
  }

  @override
  String getReason() {
    if (!_initialized) {
      return "";
    }
    return _ws.closeReason ?? "";
  }

  /// [Websocket.connecting], [Websocket.open], [Websocket.closing], [Websocket.closed]
  @override
  int getState() {
    if (!_initialized) {
      return WebSocket.connecting;
    }
    return _ws.innerWebSocket?.readyState ?? WebSocket.connecting;
  }

  @override
  Stream? getStream() {
    if (!_initialized) {
      return null;
    }
    return _msgSc.stream;
  }

  @override
  Future<_Ws> connect() async {
    return WebSocket.connect(_url).then((value) {
      _ws = IOWebSocketChannel(value);
      _initialized = true;
      _init(_ws);
      return this;
    });
  }

  @override
  Future<void> send(dynamic message) async {
    if (!_initialized) {
      throw WsException(
          WsException.codeNotConnectedYet, "connection not initialized");
    }
    if (_ws.closeCode != null) {
      throw WsException(
          WsException.codeClosed, "ws is closed, close code: ${_ws.closeCode}");
    }
    try {
      var json = _jsonEncoder.convert(message);
      Logger.debug(_tag, "[send]\t$json");
      _ws.sink.add(json);
    } catch (e) {
      Logger.err(_tag, e);
    }
    return message;
  }

  @override
  Future<dynamic> close() async {
    if (!_initialized) {
      return Future.value();
    }
    _msgSc.close();
    return _ws.sink.close(status.normalClosure, "close");
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

  _Ws _init(IOWebSocketChannel ws) {
    _ws.stream.listen(_onMessage, onError: _onError, onDone: _onDone);
    return this;
  }

  void _onError(dynamic error) {
    Logger.err(_tag, "on error $error");
    if (_ws.closeCode != null) {
      _stateSc.add(_ws.closeCode ?? 0);
    }
    _msgSc.addError(error);
  }

  void _onDone() {
    Logger.debug(_tag, "closed: ${_ws.closeCode} ${_ws.closeReason}");
    _stateSc.add(_ws.closeCode ?? 0);
  }

  void _onMessage(dynamic message) {
    Logger.debug(_tag, "[recv]\t$message");
    if (message == "PONG") {
      Logger.debug(_tag, "pong");
      return;
    }
    _msgSc.add(message);
  }
}
