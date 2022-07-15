import 'dart:async';
import 'dart:convert';
import 'dart:io';

abstract class WsConnection {
  Future<WsConnection> connect();

  Future<void> close();

  Future<void> send(dynamic message);
}

class Ws extends WsConnection {
  final String _url;
  late WebSocket _ws;

  void Function(dynamic message)? _asyncMessageListener;
  void Function(int state, bool reconnecting)? stateChangeListener;

  Ws(this._url);

  @override
  Future<Ws> connect() => WebSocket.connect(_url).then((value) => _init(_ws));

  @override
  Future<void> send(dynamic message) async {
    var json = JsonEncoder().convert(message);
    _ws.add(json);
    return message;
  }

  @override
  close() => _ws.close();

  void onMessage(void Function(dynamic message)? listener) {
    _asyncMessageListener = listener;
  }

  void startHeartbeat() {
    Timer(Duration(seconds: 30), () {
      send({});
      startHeartbeat();
    });
  }

  void onSateChange(cb) {}

  void _checkAlive() {
    if (_ws.readyState == WebSocket.closed &&
        _ws.closeCode != WebSocketStatus.normalClosure) {
      print("reconnecting");
      connect();
    }
  }

  Ws _init(WebSocket ws) {
    _ws = ws;
    _ws.listen(_onMessage,
        onError: _onError, onDone: _onDone, cancelOnError: true);
    _ws.pingInterval = Duration(seconds: 30);
    return this;
  }

  void _onError(dynamic error) {
    print('error: $error');
    _checkAlive();
  }

  void _onDone() {
    print('done');
  }

  void _onMessage(message) {
    print('received: $message');
    if (_asyncMessageListener != null) {
      _asyncMessageListener!(message);
    }
  }
}
