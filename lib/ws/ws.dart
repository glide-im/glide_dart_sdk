import 'dart:convert';
import 'dart:io';

class Options {
  int? connectTimeout;
}

class Ws {
  final String _url;
  late WebSocket _ws;

  Ws(this._url);

  factory Ws.fromUrl(String url) => Ws(url);

  void startDaemon() {}

  Future<Ws> connect() async {
    return WebSocket.connect(_url).then((value) {
      _init(value);
      return this;
    });
  }

  void _init(WebSocket value) {
    _ws = value;
    _ws.listen(_onMessage);
  }

  void send(Object object) {
    _ws.add(JsonEncoder().convert(object));
  }

  void _onMessage(message) {
    print('received: $message');
  }
}
