import 'dart:async';
import 'dart:io';

import 'package:glide_dart_sdk/glide_dart_sdk.dart';

void main() async {
  final glide = Glide();

  Glide.setLogger(stdout.nonBlocking);

  await glide.init().last;
  glide.sessionManager.events().listen((event) {
    if (event.type == SessionEventType.sessionAdded) {
      glide.sessionManager
          .get(event.id)
          .then((value) => initWorkChannel(value));
    }
  });

  final bean = await glide.guestLogin("test", "");
  await glide.initCache(bean.uid.toString());
  await glide.connect(bean);
  await glide.sessionManager.whileInitialized();

  await delay(20);
  final sessions = await glide.sessionManager.getSessions();
  for (var ses in sessions) {
    print("${ses.info}");
  }
  await glide.logout();
}

Future delay(int second) async {
  await Future.delayed(Duration(seconds: second));
}

void initWorkChannel(GlideSession? session) async {
  if (session == null) return;
  if (session.info.id == 'the_world_channel') {
    await delay(3);
    await session.sendTextMessage("Hello");
  }
}
