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

  final String tag = "Context";

  Context({
    required this.api,
    required this.ws,
    required this.sessionCache,
    required this.messageCache,
    required this.myId,
    required this.sessionEventInterceptor,
  }) {
    event.stream.listen((event) {
      // Logger.info(tag, "global event: source=${event.source}, event=${event.event}");
    });
  }
}

class GlobalEvent {
  final String source;
  final dynamic event;

  GlobalEvent({required this.source, required this.event});
}

mixin class SubscriptionManger {
  Set<StreamSubscription> subscriptions = {};

  void dispose() {
    for (var subscription in subscriptions) {
      subscription.cancel();
    }
  }

  void addSubscription(StreamSubscription subscription) {
    subscriptions.add(subscription);
  }

  void removeSubscription(StreamSubscription subscription) {
    subscriptions.remove(subscription);
  }
}
