import 'dart:convert';
import 'dart:io';

class Ws {
  final String _url;
  late WebSocket _ws;

  Ws(this._url);

  Future<Ws> connect() async {
    return WebSocket.connect(_url).then((value) {
      _ws = value;
      _ws.listen(_onMessage);
      return this;
    });
  }

  void send(Object object) {
    _ws.add(JsonEncoder().convert(object));
  }

  void _onMessage(message) {
    print('received: $message');
  }
}
