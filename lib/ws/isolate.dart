import 'dart:async';
import 'dart:isolate';

class IsolateX {
  late ReceivePort _receivePort;
  late SendPort _sendPort;
  late Isolate _isolate;

  IsolateX();

  Future<IsolateX> start() async {
    _receivePort = ReceivePort("isolatex");
    _isolate = await Isolate.spawn(_duplex, _receivePort.sendPort);
    var sendPort = await _receivePort.take(1).first;
    if (sendPort is SendPort) {
      _sendPort = sendPort;
    }
    return this;
  }

  void stop() {
    _isolate.kill();
  }

  void send(String message) {
    _sendPort.send(message);
  }

  void receive(void Function(String message) callback) {
    _receivePort.listen((message) {
      if (message is String) {
        callback(message);
      }
    });
  }

  void _simplexRec(dynamic message) {}

  void _simplexSend(dynamic message) {}

  void _duplex(SendPort sendPort) async {
    var r = ReceivePort();
    sendPort.send(r.sendPort);

    await for (var m in r) {
      _onReceive(m);
    }
    sendPort.send(null);
  }

  void _onReceive(dynamic message) {
    print('received: $message');
  }
}
