import 'dart:async';

import 'package:glide_dart_sdk/src/context.dart';
import 'package:glide_dart_sdk/src/messages.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:rxdart/rxdart.dart';

import 'errors.dart';
import 'session.dart';

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
  factory SessionManagerInternal(Context ctx) => _SessionManagerImpl(ctx);

  Stream<String> init();

  Stream<String> onMessage(Action action, GlideChatMessage message);

  Stream<String> onClientMessage(Action action, GlideChatMessage message);

  void onAck(Action action, GlideAckMessage message);
}

class _SessionManagerImpl implements SessionManagerInternal {
  final Map<String, GlideSessionInternal> id2session = {};
  Context ctx;
  bool initialized = false;

  final String source = "session-manager";

  _SessionManagerImpl(this.ctx);

  @override
  Stream<String> init() async* {
    final cachedSession = await ctx.sessionCache.getSessions();
    await Future.delayed(Duration(seconds: 1));
    for (var info in cachedSession) {
      id2session[info.id] = GlideSessionInternal.create(info, ctx);
    }
    initialized = true;
  }

  @override
  Future<GlideSession> create(String to, SessionType type) async {
    GlideSessionInfo? si = GlideSessionInfo.create2(to, type);
    si = ctx.sessionEventInterceptor.onSessionCreate(si);
    if (si == null) {
      throw GlideException(message: "session create rejected");
    }
    GlideSessionInternal session = GlideSessionInternal.create(si, ctx);
    if (id2session.containsKey(to)) {
      throw GlideException(message: "session already exists");
    }
    id2session[session.info.id] = session;
    await ctx.sessionCache.addSession(session.info);
    ctx.event.add(GlobalEvent(
      source: source,
      event: SessionEvent(
        type: SessionEventType.sessionAdded,
        id: session.info.id,
      ),
    ));
    return session;
  }

  @override
  Stream<String> onMessage(Action action, GlideChatMessage cm) async* {
    if (action == Action.messageGroupNotify) {
      yield "$source message ignored";
      return;
    }
    final target = cm.to == ctx.myId ? cm.from : cm.to;
    GlideSessionInternal? session = id2session[target];

    ctx.ws
        .send(ProtocolMessage.ackRequest(cm.from, cm.mid))
        .execute()
        .onError((error, stackTrace) {
      Logger.err("message ack error", error);
    });
    yield "$source message acked";

    if (session == null) {
      final type = cm.to != ctx.myId ? SessionType.channel : SessionType.chat;
      session = await create(target, type) as GlideSessionInternal;
      yield "$source session created ${session.info.id}";
    }
    final ncm =
        ctx.sessionEventInterceptor.onInterceptMessage(session.info, cm);
    if (ncm == null) {
      yield "message intercepted";
      return;
    }
    yield* session.onMessage(ncm);

    final increment =
        ctx.sessionEventInterceptor.onIncrementUnread(session.info, ncm);
    session.addUnread(increment);

    yield "$source notify update";
    ctx.event.add(GlobalEvent(
      source: source,
      event: SessionEvent(
        type: SessionEventType.sessionUpdated,
        id: session.info.id,
      ),
    ));
  }

  @override
  Stream<String> onClientMessage(Action action, GlideChatMessage message) async* {
    yield "$source cli message ignored";

  }

  @override
  void onAck(Action action, GlideAckMessage message) {
    final session = id2session[message.from];
    if (session == null) {
      Logger.err(source, "session not found: ${message.from}");
    }
    session?.onAck(action, message);
  }

  @override
  Stream<SessionEvent> events() {
    return ctx.event.stream.mapNotNull((e) {
      if (e.event is SessionEvent) {
        return e.event;
      }
      return null;
    });
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
