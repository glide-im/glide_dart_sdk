import 'dart:isolate';

class Daemon {
  late Isolate _isolate;

  stop() {
    _isolate.kill();
  }

  Future<Isolate> daemonize() {
    var p = ReceivePort("daemon");
    return Isolate.spawn(_start, p.sendPort).then((value) {
      _isolate = value;
      return value;
    });
  }

  void _start(SendPort port) {
    print('start isolate');
  }
}
