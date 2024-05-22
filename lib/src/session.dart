import 'dart:async';

import 'package:glide_dart_sdk/src/api/session_api.dart';
import 'package:glide_dart_sdk/src/session_manager.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:rxdart/rxdart.dart';

import 'context.dart';
import 'messages.dart';

enum SessionType {
  chat,
  channel;
}

class GlideSessionInfo {
  final String id;
  final String ticket;
  final String to;
  final String title;
  final num unread;
  final String lastMessage;
  final num createAt;
  final num updateAt;
  final num lastReadAt;
  final num lastReadSeq;
  final SessionType type;

  GlideSessionInfo({
    required this.id,
    required this.ticket,
    required this.to,
    required this.title,
    required this.unread,
    required this.lastMessage,
    required this.createAt,
    required this.updateAt,
    required this.lastReadAt,
    required this.lastReadSeq,
    required this.type,
  });

  factory GlideSessionInfo.create2(String to, SessionType type) {
    return GlideSessionInfo.create(to, to, type);
  }

  factory GlideSessionInfo.create(String to, String title, SessionType type) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return GlideSessionInfo(
      id: to,
      ticket: "",
      to: to,
      title: title,
      unread: 0,
      lastMessage: "session created",
      createAt: now,
      updateAt: now,
      lastReadAt: now,
      lastReadSeq: 0,
      type: type,
    );
  }

  GlideSessionInfo copyWith({
    String? id,
    String? ticket,
    String? to,
    String? title,
    num? unread,
    String? lastMessage,
    num? createAt,
    num? updateAt,
    num? lastReadAt,
    num? lastReadSeq,
    SessionType? type,
  }) {
    return GlideSessionInfo(
      id: id ?? this.id,
      ticket: ticket ?? this.ticket,
      to: to ?? this.to,
      title: title ?? this.title,
      unread: unread ?? this.unread,
      lastMessage: lastMessage ?? this.lastMessage,
      createAt: createAt ?? this.createAt,
      updateAt: updateAt ?? this.updateAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadSeq: lastReadSeq ?? this.lastReadSeq,
      type: type ?? this.type,
    );
  }

  @override
  String toString() {
    return 'GlideSessionInfo{id: $id, to: $to, title: $title, unread: $unread, ticket: $ticket, lastMessage: $lastMessage, createAt: $createAt, updateAt: $updateAt, lastReadAt: $lastReadAt, lastReadSeq: $lastReadSeq, type: $type}';
  }
}

abstract interface class GlideMessageCache {
  Future<List<GlideChatMessage>> getMessages(String sessionId);

  Future<void> addMessage(String sessionId, GlideChatMessage message);

  Future<bool> hasMessage(num mid);

  Future<void> removeMessage(String sessionId, String id);

  Future<void> updateMessage(String sessionId, GlideChatMessage message);

  Future clear();
}

class GlideMessageMemoryCache implements GlideMessageCache {
  final Map<String, List<GlideChatMessage>> _cache = {};
  final Set<num> mids = {};

  @override
  Future<void> addMessage(String sessionId, GlideChatMessage message) async {
    if (!_cache.containsKey(sessionId)) {
      _cache[sessionId] = [];
    }
    _cache[sessionId]?.add(message);
    mids.add(message.mid);
  }

  @override
  Future<bool> hasMessage(num mid) async {
    return mids.contains(mid);
  }

  @override
  Future clear() async {
    _cache.clear();
  }

  @override
  Future<List<GlideChatMessage>> getMessages(String sessionId) async {
    return _cache[sessionId] ?? [];
  }

  @override
  Future<void> removeMessage(String sessionId, String id) async {
    _cache[sessionId]?.removeWhere((element) => element.mid.toString() == id);
  }

  @override
  Future<void> updateMessage(String sessionId, GlideChatMessage message) async {
    final idx =
        _cache[sessionId]?.indexWhere((element) => element.mid == message.mid);
    if (idx != null && idx >= 0) {
      _cache[sessionId]?[idx] = message;
    }
  }
}

abstract interface class GlideSession {
  GlideSessionInfo get info;

  Future clearUnread();

  Future addUnread(int count);

  Future sendTextMessage(String content);

  void onTypingEvent();

  Future recallMessage(String mid);

  Future<List<GlideChatMessage>> history();

  Stream<GlideChatMessage> messages();
}

abstract interface class GlideSessionInternal extends GlideSession {
  factory GlideSessionInternal(
    Context ctx,
    String to,
    SessionType type,
  ) =>
      GlideSessionInternal.create(GlideSessionInfo.create2(to, type), ctx);

  factory GlideSessionInternal.create(GlideSessionInfo info, Context ctx) =>
      _GlideSessionInternalImpl(info, ctx);

  Stream<String> onMessage(GlideChatMessage message);
}

class _GlideSessionInternalImpl implements GlideSessionInternal {
  GlideSessionInfo i;
  final Context ctx;

  String get source => "session-${i.id}";

  _GlideSessionInternalImpl(this.i, this.ctx);

  @override
  Stream<String> onMessage(GlideChatMessage message) async* {
    yield "session_${i.id} received";
    if (await ctx.messageCache.hasMessage(message.mid)) {
      await ctx.messageCache.updateMessage(i.id, message);
      yield "message exist";
      return;
    }
    await ctx.messageCache.addMessage(i.id, message);
    i = i.copyWith(
      lastMessage: message.content.toString(),
      updateAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _save();
    yield "session updated";
    ctx.event.add(GlobalEvent(source: source, event: message));
  }

  @override
  Future clearUnread() async {
    i = i.copyWith(unread: 0);
    await _save();
  }

  @override
  Future addUnread(int count) async {
    i = i.copyWith(unread: i.unread + count);
    await _save();
  }

  @override
  Future recallMessage(String mid) async {
    // todo
  }

  @override
  Future<List<GlideChatMessage>> history() async {
    return await ctx.messageCache.getMessages(i.id);
  }

  @override
  Stream<GlideChatMessage> messages() {
    return ctx.event.stream.mapNotNull((event) {
      final ev = event.event;
      if (event.source == source && ev is GlideChatMessage) {
        return ev;
      }
      return null;
    });
  }

  @override
  void onTypingEvent() {
    // TODO: implement onTypingEvent
  }

  @override
  Future sendTextMessage(String content) async {
    final cm = GlideChatMessage(
      mid: DateTime.now().millisecondsSinceEpoch,
      seq: 0,
      from: ctx.myId,
      to: info.id,
      type: 1,
      content: content,
      sendAt: DateTime.now().millisecondsSinceEpoch,
    );
    String ticket = info.ticket;
    if (ticket.isEmpty) {
      final bean = await SessionApi.getTicket(info.to);
      ticket = bean.ticket;
    }
    final action = info.type == SessionType.channel
        ? Action.messageGroup
        : Action.messageChat;
    await ctx.ws.sendChatMessage(action, cm, ticket).execute();
    ctx.messageCache.addMessage(i.id, cm);
    ctx.event.add(GlobalEvent(source: source, event: cm));
    i = i.copyWith(
      lastMessage: cm.content.toString(),
      updateAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _save();
  }

  @override
  GlideSessionInfo get info => i;

  Future _save() async {
    await ctx.sessionCache.updateSession(i);
    ctx.event.add(GlobalEvent(
      source: source,
      event: SessionEvent(
        id: info.id,
        type: SessionEventType.sessionUpdated,
      ),
    ));
  }
}
