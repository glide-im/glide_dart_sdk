import 'package:glide_dart_sdk/src/api/auth_api.dart';
import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:test/test.dart';

void main() {
  Http.init("");

  test("test guest login", () async {
    final res = await AuthApi().loginGuest("nickname", "avatar");
    print(res);
  });
}
