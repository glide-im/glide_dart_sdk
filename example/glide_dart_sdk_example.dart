import 'package:glide_dart_sdk/glide_dart_sdk.dart';

void main() async {
  final glide = Glide();
  await glide.init();
  await glide.guestLogin("avatar", "2");
  await delay(1);

  glide.sessionManager.events().listen((event) {
    print("event: $event");
    if (event.type == SessionEventType.sessionAdded) {
      glide.sessionManager
          .get(event.id)
          .then((value) => initWorkChannel(value));
    }
  });

  await glide.sessionManager.whileInitialized();

  await delay(10);
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
