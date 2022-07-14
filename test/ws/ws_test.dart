import 'dart:io';
import 'dart:isolate';

import 'package:dart_sdk/ws/isolate.dart';
import 'package:dart_sdk/ws/ws.dart';
import 'package:test/scaffolding.dart';

void main() {
  test("isolatex", () async {

    final isolatex = IsolateX();
    isolatex.start().then((value) {
      isolatex.send("hello");
      isolatex.receive((message) {
        print(message);
      });
    }).onError((error, stackTrace) {
      print(error);
      print(stackTrace);
    });
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
