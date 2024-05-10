import 'package:glide_dart_sdk/src/glide.dart';

void main() async {
  final glide = Glide();

  await glide.guestLogin("avatar", "2");
  delay(2);
  glide.disconnect();
}

Future delay(int second) async {
  await Future.delayed(Duration(seconds: second));
}
