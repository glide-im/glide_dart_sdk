import 'dart:async';

import 'package:glide_dart_sdk/src/messages.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';

import 'session.dart';
import 'ws/ws_im_client.dart';

typedef ShouldCountUnread = bool Function(GlideSessionInfo);

abstract interface class SessionListCache {
  Future<List<GlideSessionInfo>> getSessions();

  Future<void> setSessions(List<GlideSessionInfo> sessions);

  Future<void> addSession(GlideSessionInfo session);

  Future<void> removeSession(String id);

  Future<void> updateSession(GlideSessionInfo session);

  Future clear();
}

class SessionListMemoryCache implements SessionListCache {
  final List<GlideSessionInfo> _sessions = [];

  @override
  Future<List<GlideSessionInfo>> getSessions() async {
    return _sessions;
  }

  @override
  Future<void> setSessions(List<GlideSessionInfo> sessions) async {
    _sessions.clear();
    _sessions.addAll(sessions);
  }

  @override
  Future<void> addSession(GlideSessionInfo session) async {
    _sessions.add(session);
  }

  @override
  Future<void> removeSession(String id) async {
    _sessions.removeWhere((element) => element.id == id);
  }

  @override
  Future<void> updateSession(GlideSessionInfo session) async {
    final idx = _sessions.indexWhere((element) => element.id == session.id);
    if (idx >= 0) {
      _sessions[idx] = session;
    }
  }

  @override
  Future clear() async {
    _sessions.clear();
  }
}

enum SessionEventType {
  sessionAdded,
  sessionRemoved,
  sessionUpdated,
}

class SessionEvent {
  final SessionEventType type;
  final String id;

  SessionEvent({required this.type, required this.id});

  @override
  String toString() {
    return 'SessionEvent{type: $type, id: $id}';
  }
}

abstract interface class SessionManager {
  Future whileInitialized();

  Future<GlideSession?> get(String id);

  Future<GlideSession> create(String target, SessionType type);

  Future<List<GlideSession>> getSessions();

  Stream<SessionEvent> events();

  Future<void> clear();
}

abstract interface class SessionManagerInternal extends SessionManager {
  factory SessionManagerInternal(GlideWsClient ws) =>
      _SessionManagerImpl(cache: SessionListMemoryCache(), ws: ws);

  Stream<String> init();

  void setMyId(String id);

  Stream<String> onMessage(
      ProtocolMessage message, ShouldCountUnread shouldCountUnread);
}

class _SessionManagerImpl implements SessionManagerInternal {
  final Map<String, GlideSessionInternal> id2session = {};
  final SessionListCache cache;
  final GlideWsClient ws;
  late String myId;
  bool initialized = false;
  final StreamController<SessionEvent> eventController =
      StreamController.broadcast(onCancel: () {}, onListen: () {});

  _SessionManagerImpl({required this.cache, required this.ws});

  @override
  void setMyId(String id) {
    myId = id;
  }

  @override
  Stream<String> init() async* {
    final cachedSession = await cache.getSessions();
    await Future.delayed(Duration(seconds: 1));
    for (var info in cachedSession) {
      id2session[info.id] = GlideSessionInternal.create(info, myId, cache, ws);
    }
    initialized = true;
  }

  @override
  Future<GlideSession> create(String to, SessionType type) async {
    final session = GlideSessionInternal(myId, to, ws, cache, type);
    id2session[session.info.id] = session;
    await cache.addSession(session.info);
    eventController.add(SessionEvent(
      type: SessionEventType.sessionAdded,
      id: session.info.id,
    ));
    return session;
  }

  @override
  Stream<String> onMessage(
      ProtocolMessage message, ShouldCountUnread shouldCountUnread) async* {
    if (message.action == Action.messageGroupNotify) {
      yield "message ignored";
      return;
    }
    GlideChatMessage cm = GlideChatMessage.fromJson(message.data);
    final target = cm.to == myId ? cm.from : cm.to;
    GlideSessionInternal? session = id2session[target];

    if (session == null) {
      final type = cm.to != myId ? SessionType.channel : SessionType.chat;
      session = await create(target, type) as GlideSessionInternal;
      yield "session created ${session.info.id}";
    }
    yield* session.onMessage(cm);
    if (shouldCountUnread(session.info)) {
      session.addUnread(1);
    }
    eventController.add(SessionEvent(
      type: SessionEventType.sessionUpdated,
      id: session.info.id,
    ));
  }

  @override
  Stream<SessionEvent> events() {
    return eventController.stream;
  }

  @override
  Future<GlideSession?> get(String id) async {
    return id2session[id];
  }

  @override
  Future whileInitialized() async {
    while (!initialized) {
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  @override
  Future<List<GlideSession>> getSessions() async {
    await whileInitialized();
    return id2session.values.toList();
  }

  @override
  Future<void> clear() async {
    id2session.clear();
  }
}
