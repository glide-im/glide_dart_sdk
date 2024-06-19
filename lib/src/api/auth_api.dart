import 'bean/auth_bean.dart';
import 'http.dart';

class AuthApi {
  const AuthApi();

  Future<AuthBean> loginToken(String token) => Http.post(
        "auth/token",
        {"Token": token},
        AuthBean.fromJson,
      );

  Future<AuthBean> loginGuest(String nickname, String avatar) => Http.post(
        "auth/guest",
        {
          "nickname": nickname,
          "avatar": avatar,
        },
        AuthBean.fromJson,
      );

  Future<AuthBean> loginPassword(String phone, String password) => Http.post(
        "auth/signin_v2",
        {
          "device": 0,
          "email": phone,
          "password": password,
        },
        AuthBean.fromJson,
      );
}
