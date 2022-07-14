import 'dart:convert';
import 'dart:io';

typedef MessageListener<T> = void Function(T message);

class Options {
  int? connectTimeout;
}

class Ws {
  final String _url;
  late WebSocket _ws;

  MessageListener? _asyncMessageListener;

  Ws(this._url);

  factory Ws.fromUrl(String url) => Ws(url);

  Future<Ws> connect() {
    return WebSocket.connect(_url).then((value) {
      _init(_ws);
      return this;
    });
  }

  void send(Object object) {
    _ws.add(JsonEncoder().convert(object));
  }

  void setMessageListener(MessageListener? listener) {
    _asyncMessageListener = listener;
  }

  void startDaemon() {

  }

  void _init(WebSocket value) {
    _ws = value;
    _ws.listen(_onMessage,
        onError: _onError, onDone: _onDone, cancelOnError: true);
  }

  void _onError(dynamic error) {
    print('error: $error');
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
