import 'dart:async';

import 'package:glide_dart_sdk/src/api/apis.dart';

import 'session.dart';
import 'session_manager.dart';
import 'ws/ws_im_client.dart';

class Context {
  GlideWsClient ws;
  SessionListCache sessionCache;
  GlideMessageCache messageCache;
  String myId;
  GlideApi api;
  SessionEventInterceptor sessionEventInterceptor;

  // global event
  StreamController<GlobalEvent> event = StreamController.broadcast();

  Context({
    required this.api,
    required this.ws,
    required this.sessionCache,
    required this.messageCache,
    required this.myId,
    required this.sessionEventInterceptor,
  });
}

class GlobalEvent {
  final String source;
  final dynamic event;

  GlobalEvent({required this.source, required this.event});
}
