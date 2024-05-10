import 'bean/auth_bean.dart';
import 'http.dart';

class AuthApi {
  static Future<AuthBean> loginToken(String token) => Http.post(
        "auth/token",
        {"Token": token},
        AuthBean.fromJson,
      );

  static Future<AuthBean> loginGuest(String nickname, String avatar) =>
      Http.post(
        "auth/guest",
        {
          "nickname": nickname,
          "avatar": avatar,
        },
        AuthBean.fromJson,
      );

  static Future<AuthBean> loginPassword(String phone, String password) =>
      Http.post(
        "auth/login",
        {
          "phone": phone,
          "password": password,
        },
        AuthBean.fromJson,
      );
}
