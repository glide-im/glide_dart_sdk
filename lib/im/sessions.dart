import 'package:dart_sdk/im/session.dart';

abstract class SessionList {
  Future<Session> getSession(String id);

  Future<Session> createSession(String id);

  Future<void> deleteSession(String id, {bool reserveHistory = false});

  Future<List<Session>> getSessions();

  void subscribeSessionUpdate(void Function(Session session) callback);
}
