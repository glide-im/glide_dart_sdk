import 'package:glide_dart_sdk/src/glide.dart';

void main() async {
  final glide = Glide();

  await glide.guestLogin("avatar", "2");
  delay(1);

  glide.sessionManager.events().listen((event) {
    print("event: $event");
  });

  await glide.sessionManager.whileInitialized();

  glide.sessionManager.getSessions().then((sessions) {
    print("sessions: $sessions");
  });

  delay(2);
  await glide.logout();
}

Future delay(int second) async {
  await Future.delayed(Duration(seconds: second));
}
