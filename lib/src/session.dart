import 'dart:async';

import 'package:glide_dart_sdk/src/api/session_api.dart';
import 'package:glide_dart_sdk/src/session_manager.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:glide_dart_sdk/src/ws/ws_im_client.dart';

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

  Future<void> removeMessage(String sessionId, String id);

  Future<void> updateMessage(String sessionId, GlideChatMessage message);

  Future clear();
}

class GlideMessageMemoryCache implements GlideMessageCache {
  final Map<String, List<GlideChatMessage>> _cache = {};

  @override
  Future<void> addMessage(String sessionId, GlideChatMessage message) async {
    if (!_cache.containsKey(sessionId)) {
      _cache[sessionId] = [];
    }
    _cache[sessionId]?.add(message);
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
  factory GlideSessionInternal(String myId, String to, GlideWsClient ws,
          SessionListCache sessionListCache, SessionType type) =>
      GlideSessionInternal.create(
          GlideSessionInfo.create2(to, type), myId, sessionListCache, ws);

  factory GlideSessionInternal.create(GlideSessionInfo info, String myId,
          SessionListCache sessionListCache, GlideWsClient ws) =>
      _GlideSessionInternalImpl(
          myId, info, GlideMessageMemoryCache(), sessionListCache, ws);

  Stream<String> onMessage(GlideChatMessage message);
}

class _GlideSessionInternalImpl implements GlideSessionInternal {
  GlideSessionInfo i;
  final GlideMessageCache cache;
  final SessionListCache sessionListCache;
  final GlideWsClient ws;
  final StreamController<GlideChatMessage> _messageSc =
      StreamController.broadcast();
  final String myId;

  _GlideSessionInternalImpl(
      this.myId, this.i, this.cache, this.sessionListCache, this.ws);

  @override
  Stream<String> onMessage(GlideChatMessage message) async* {
    yield "session_${i.id} received";
    await cache.addMessage(i.id, message);
    i = i.copyWith(
      lastMessage: message.content.toString(),
      updateAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _save();
    yield "session updated";
    _messageSc.add(message);
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
    return await cache.getMessages(i.id);
  }

  @override
  Stream<GlideChatMessage> messages() {
    return _messageSc.stream;
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
      from: myId,
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
    await ws.sendChatMessage(action, cm, ticket).execute();
  }

  @override
  GlideSessionInfo get info => i;

  Future _save() async {
    await sessionListCache.updateSession(i);
  }
}
