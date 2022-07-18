import 'package:dart_sdk/im/session.dart';

enum UpdateType {
  add,
  remove,
  update,
}

typedef UpdateListener = void Function(UpdateType type, Session session);

abstract class SessionList {
  bool isExist(String id);

  Future<Session?> getSession(String id);

  Future<Session> createSession(String id);

  Future<void> deleteSession(String id, {bool reserveHistory = false});

  Future<List<Session>> getSessions();

  void onUpdate(UpdateListener listener);

  void removeUpdate(UpdateListener listener);
}

class SessionListImpl implements SessionList {

  final Map<String, Session> _sessions = {};
  final List<UpdateListener> _listeners = [];
  final List<Session> _sessionsList = [];

  @override
  bool isExist(String id) {
    return _sessions.containsKey(id);
  }

  @override
  Future<Session?> getSession(String id) async {
    if (_sessions.containsKey(id)) {
      return _sessions[id];
    }
    return null;
  }

  @override
  Future<Session> createSession(String id) async {
    if (_sessions.containsKey(id)) {
      return _sessions[id]!;
    }
    final session = SessionImpl(this, id);
    _sessions[id] = session;
    _sessionsList.add(session);
    _notifyUpdate(UpdateType.add, session);
    return session;
  }

  @override
  Future<void> deleteSession(String id, {bool reserveHistory = false}) async {
    if (!_sessions.containsKey(id)) {
      return;
    }
    final session = _sessions[id]!;
    _sessions.remove(id);
    _sessionsList.remove(session);
    _notifyUpdate(UpdateType.remove, session);
    await session.delete(reserveHistory: reserveHistory);
  }

  @override
  Future<List<Session>> getSessions() async {
    return _sessionsList;
  }

  @override
  void onUpdate(UpdateListener listener) {
    _listeners.add(listener);
  }

  @override
  void removeUpdate(UpdateListener listener) {
    _listeners.remove(listener);
  }

  void _notifyUpdate(UpdateType type, Session session) {
    for (final listener in _listeners) {
      listener(type, session);
    }
  }
}
