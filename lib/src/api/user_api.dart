import 'package:glide_dart_sdk/src/api/bean/user_info_bean.dart';

import 'http.dart';

class UserApi {
  const UserApi();

  Future<List<UserInfoBean>> getUserInfo(List<num> uids) => Http.post(
      "user/info", {"Uid": uids}, ListFactory(UserInfoBean.fromMap).call);
}
