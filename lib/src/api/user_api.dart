import 'http.dart';

class SessionApi {
  static Future getUserInfo(List<String> uids) =>
      Http.post("user/info", {"Uid": uids});
}
