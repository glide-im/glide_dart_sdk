import 'dart:async';

import 'session.dart';
import 'session_manager.dart';
import 'ws/ws_im_client.dart';

class Context {
  GlideWsClient ws;
  SessionListCache sessionCache;
  GlideMessageCache messageCache;
  String myId;

  // global event
  StreamController<GlobalEvent> event = StreamController.broadcast();

  Context({
    required this.ws,
    required this.sessionCache,
    required this.messageCache,
    required this.myId,
  });
}

class GlobalEvent {
  final String source;
  final dynamic event;

  GlobalEvent({required this.source, required this.event});
}
