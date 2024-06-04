import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:glide_dart_sdk/src/api/user_api.dart';
import 'package:glide_dart_sdk/src/config.dart';
import 'package:test/test.dart';

void main() {
  Http.init(Configs.apiBaseUrl);
  Http.setToken(
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3MTgwODU0MzksInVpZCI6NTQ2MzgyLCJkZXZpY2UiOi0xLCJ2ZXIiOjEsImFwcF9pZCI6MX0.t1LFvtNVS0Wlsac1wtyNxjg9um2EI15VKkHlY-RKSXU");

  test("test get user info", () async {
    final res = await UserApi().getUserInfo([546382]);
    print(res[0]);
  });
}
