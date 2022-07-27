import 'dart:async';
import 'dart:isolate';

import 'package:rxdart/rxdart.dart';


class IsolateX {
  late ReceivePort _receivePort;
  late Stream<dynamic> _stream;
  late SendPort _sendPort;
  late Isolate _isolate;

  IsolateX();

  Future<IsolateX> start() async {
    _receivePort = ReceivePort("isolatex");
    _isolate = await Isolate.spawn(_duplex, _receivePort.sendPort);

    _stream = _receivePort.share();
    _sendPort = await _stream.first;

    print("spawned isolate");
    _stream.listen((message) {
      if (message == null) {
        _receivePort.close();
        print("received port closed message");
        return;
      }
      if (message is SendPort) {
        _sendPort = message;
      }
      print("received: $message");
    }, onError: (error, stackTrace) {
      print(error);
      print(stackTrace);
    }, onDone: () {
      print("done");
    });

    _receivePort.doOnCancel(() {
      print("canceled");
    });

    return this;
  }

  void stop() {
    send(null);
  }

  void send(dynamic message) {
    _sendPort.send(message);
  }

  void receive(void Function(String message) callback) {
    _stream.listen((message) {
      if (message is String) {
        callback(message);
      }
    });
  }

  static void _duplex(SendPort p) async {
    var r = ReceivePort();
    p.send(r.sendPort);
    await for (var m in r) {
      if (m == null) {
        r.close();
        break;
      }
      _onReceive(m);
    }
    p.send(null);
    Isolate.current.kill(priority: Isolate.immediate);
  }

  static void _onReceive(dynamic message) {
    // print('received: $message');
  }
}
