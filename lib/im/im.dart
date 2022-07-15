abstract class IM {
  Future<dynamic> auth();

  Future<dynamic> login({String account, String password});

  Future<dynamic> getMyInfo();

  Stream<dynamic> subscribeMessage();
}
