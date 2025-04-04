import 'dart:async';

import 'package:glide_dart_sdk/src/context.dart';
import 'package:glide_dart_sdk/src/message.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:rxdart/rxdart.dart';

import 'errors.dart';
import 'session.dart';

abstract interface class SessionListCache {
  Future init(String uid);

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
  Future init(String uid) async {
    _sessions.clear();
    return;
  }

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
  memberEnter,
  memberLeave,
  membersUpdate,
}

class SessionEvent {
  final SessionEventType type;
  final String id;
  final dynamic data;

  SessionEvent({required this.type, required this.id, this.data});

  @override
  String toString() {
    return 'SessionEvent{type: $type, id: $id, data: $data}';
  }
}

abstract interface class SessionManager {
  Future whileInitialized();

  Future<GlideSession?> get(String id);

  Future delete(String id, bool deleteMessage);

  Future<GlideSession> create(String target, SessionType type);

  Future<List<GlideSession>> getSessions();

  Stream<SessionEvent> events();

  Future<void> clear();
}

abstract interface class SessionManagerInternal extends SessionManager {
  factory SessionManagerInternal(Context ctx) => _SessionManagerImpl(ctx);

  Stream<String> init();

  Stream<String> onMessage(Action action, Message message);

  Stream<String> onClientMessage(Action action, Message message);

  Stream<String> onAck(Action action, GlideAckMessage message);
}

class _SessionManagerImpl implements SessionManagerInternal {
  final Map<String, GlideSessionInternal> id2session = {};
  Context ctx;
  bool initialized = false;

  final String source = "session-manager";

  _SessionManagerImpl(this.ctx);

  @override
  Stream<String> init() async* {
    yield "$source start init";
    await clear();
    final cachedSession = await ctx.sessionCache.getSessions();
    yield "cache session loaded, count: ${cachedSession.length}";
    for (var info in cachedSession) {
      final s = GlideSessionInternal.create(info, ctx);
      yield* s.init();
      id2session[info.id] = s;
    }
    initialized = true;
    yield "$source init done";
  }

  @override
  Future<GlideSession> create(String to, SessionType type) async {
    GlideSessionInfo? si = GlideSessionInfo.create2(to, type);
    si = await ctx.sessionEventInterceptor.onSessionCreate(si);
    if (si == null) {
      throw GlideException(message: "session create rejected");
    }
    GlideSessionInternal session = GlideSessionInternal.create(si, ctx);
    if (id2session.containsKey(to)) {
      throw GlideException(message: "session already exists");
    }
    id2session[session.info.id] = session;
    try {
      await ctx.sessionCache.addSession(session.info);
    } catch (e) {
      Logger.err("session cache add error", e);
    }
    ctx.event.add(GlobalEvent(
      source: source,
      event: SessionEvent(
        type: SessionEventType.sessionAdded,
        id: session.info.id,
      ),
    ));
    return session;
  }

  Future<GlideSessionInternal> checkSession(Message m) async {
    final sessionType = m.to != ctx.myId ? SessionType.channel : SessionType.chat;
    final target = m.to == ctx.myId ? m.from : m.to;
    GlideSessionInternal? session = id2session[target];
    if (session != null) {
      return session;
    }
    return await create(target, sessionType) as GlideSessionInternal;
  }

  Stream<String> handleGroupNotify(GlideSessionInternal session, Message m) async* {
    SessionEvent? event;
    if (m.type == EnterMessageType.instance) {
      session.onMemberStateChange([m.content], SessionMemberState.online);
      event = SessionEvent(type: SessionEventType.memberEnter, id: session.info.id, data: m.content);
    } else if (m.type == LeaveMessageType.instance) {
      event = SessionEvent(type: SessionEventType.memberLeave, id: session.info.id, data: m.content);
      session.onMemberStateChange([m.content], SessionMemberState.offline);
    } else if (m.type == NotifyMembersMessageType.instance) {
      event = SessionEvent(type: SessionEventType.membersUpdate, id: session.info.id, data: m.content);
      session.onMemberStateChange(m.content, SessionMemberState.online);
    }
    if (event != null) {
      ctx.event.add(GlobalEvent(
        source: source,
        event: event,
      ));
    }
  }

  @override
  Stream<String> onMessage(Action action, Message m) async* {
    await _initialized();
    // yield "$source onMessage, $m";
    final session = await checkSession(m);
    if (action == Action.messageGroupNotify) {
      yield* handleGroupNotify(session, m);
    }
    Message cm = m;
    final target = m.to == ctx.myId ? m.from : m.to;
    if (cm.sendAt < 171878687139) {
      cm = cm.copyWith(sendAt: DateTime.now().millisecondsSinceEpoch);
    }
    if (session.info.type == SessionType.chat && m.type.isUserMessage) {
      ctx.ws
          .send(ProtocolMessage.ackRequest(GlideAckMessage(
            mid: cm.mid,
            from: ctx.myId,
            to: target,
            cliMid: cm.cliMid,
            seq: cm.seq,
          )))
          .execute()
          .onError((error, stackTrace) {
        Logger.err("message ack error", error);
      });
      yield "$source message acked";
    }
    final ncm = ctx.sessionEventInterceptor.onInterceptMessage(session.info, cm);
    if (ncm == null) {
      yield "message intercepted";
      return;
    }
    yield* session.onMessage(ncm);

    final increment = ctx.sessionEventInterceptor.onIncrementUnread(session.info, ncm);
    await session.addUnread(increment);

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
  Stream<String> onClientMessage(Action action, Message cm) async* {
    await _initialized();
    final target = cm.to == ctx.myId ? cm.from : cm.to;
    GlideSessionInternal? session = id2session[target];
    if (session == null) {
      yield "$source session not found";
      return;
    }
    yield* session.onClientMessage(cm);
  }

  @override
  Stream<String> onAck(Action action, GlideAckMessage message) async* {
    final session = id2session[message.from] ?? id2session[message.to];
    if (session == null) {
      throw "session not found";
    }
    yield* session.onAck(action, message);
  }

  @override
  Stream<SessionEvent> events() async* {
    yield* ctx.event.stream.mapNotNull((e) {
      if (e.event is SessionEvent) {
        return e.event;
      }
      return null;
    });
  }

  @override
  Future delete(String id, bool deleteMessage) async {
    final session = id2session[id];
    if (session == null) {
      throw "session not found";
    }
    await session.close();
    await ctx.sessionCache.removeSession(id);
    if (deleteMessage) {
      await session.clear();
    }
    id2session.remove(id);
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
    id2session.forEach((key, value) {
      value.close();
    });
    id2session.clear();
  }

  Future _initialized() async {
    try {
      await whileInitialized().timeout(Duration(seconds: 10));
    } catch (e) {
      throw GlideException(message: "$source init timeout");
    }
  }
}
