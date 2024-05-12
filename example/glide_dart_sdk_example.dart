import 'package:glide_dart_sdk/src/glide.dart';
import 'package:glide_dart_sdk/src/session.dart';

void main() async {
  final glide = Glide();

  await glide.guestLogin("avatar", "2");
  await delay(1);

  glide.sessionManager.events().listen((event) {
    print("event: $event");
    glide.sessionManager.get(event.id).then((value) => initWorkChannel(value));
  });

  await glide.sessionManager.whileInitialized();

  glide.sessionManager.getSessions().then((sessions) {
    print("sessions: $sessions");
  });

  await delay(10);
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
