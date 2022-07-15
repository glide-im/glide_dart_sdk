import 'dart:io';

import 'package:dart_sdk/ws/isolate.dart';
import 'package:dart_sdk/ws/ws.dart';
import 'package:test/scaffolding.dart';

void main() {
  test("isolatex", () async {
    final isolatex = IsolateX();
    await isolatex.start();
    isolatex.send("hello 1");
    isolatex.send("hello 2");
    isolatex.stop();
    isolatex.send("hello 3");
    sleep(Duration(seconds: 3));
  });
  return;
  test('test', () async {
    var ws = Ws("ws://localhost:80/ws");
    ws.connect().then((value) {
      print("connected");
    });
    sleep(Duration(seconds: 10));
  });
}
