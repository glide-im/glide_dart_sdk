import 'package:dart_sdk/api/dto.dart';

import 'bean.dart';
import 'http.dart';

class Apis {
  static final Http _http = Http();

  static login(LoginDto dto) =>
      _http.post('auth/signin', dto, LoginBean.fromJson);

  static getUserInfo() =>
      _http.get('user/info', UserInfoBean.fromJson.toListFactory());
}
