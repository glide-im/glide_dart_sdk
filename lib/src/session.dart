import 'dart:async';

import 'package:glide_dart_sdk/src/api/session_api.dart';
import 'package:glide_dart_sdk/src/errors.dart';
import 'package:glide_dart_sdk/src/session_manager.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:glide_dart_sdk/src/ws/ws_im_client.dart';

import 'messages.dart';

class GlideSessionInfo {
  final String id;
  final String ticket;
  final String from;
  final String to;
  final String title;
  final num unread;
  final String lastMessage;
  final num createAt;
  final num updateAt;
  final num lastReadAt;
  final num lastReadSeq;

  GlideSessionInfo({
    required this.id,
    required this.ticket,
    required this.from,
    required this.to,
    required this.title,
    required this.unread,
    required this.lastMessage,
    required this.createAt,
    required this.updateAt,
    required this.lastReadAt,
    required this.lastReadSeq,
  });

  factory GlideSessionInfo.create2(String from, String to) {
    return GlideSessionInfo.create(from, to, to);
  }

  factory GlideSessionInfo.create(String from, String to, String title) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return GlideSessionInfo(
      id: to,
      ticket: "",
      from: from,
      to: to,
      title: title,
      unread: 0,
      lastMessage: "session created",
      createAt: now,
      updateAt: now,
      lastReadAt: now,
      lastReadSeq: 0,
    );
  }

  GlideSessionInfo copyWith({
    String? id,
    String? ticket,
    String? from,
    String? to,
    String? title,
    num? unread,
    String? lastMessage,
    num? createAt,
    num? updateAt,
    num? lastReadAt,
    num? lastReadSeq,
  }) {
    return GlideSessionInfo(
      id: id ?? this.id,
      ticket: ticket ?? this.ticket,
      from: from ?? this.from,
      to: to ?? this.to,
      title: title ?? this.title,
      unread: unread ?? this.unread,
      lastMessage: lastMessage ?? this.lastMessage,
      createAt: createAt ?? this.createAt,
      updateAt: updateAt ?? this.updateAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadSeq: lastReadSeq ?? this.lastReadSeq,
    );
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

  Future<List<dynamic>> history();

  Stream<GlideChatMessage> messages();
}

abstract interface class GlideSessionInternal extends GlideSession {
  factory GlideSessionInternal(String from, String to, GlideWsClient ws,
          SessionListCache sessionListCache) =>
      GlideSessionInternal.create(
          GlideSessionInfo.create2(from, to), sessionListCache, ws);

  factory GlideSessionInternal.create(GlideSessionInfo info,
          SessionListCache sessionListCache, GlideWsClient ws) =>
      _GlideSessionInternalImpl(
          info, GlideMessageMemoryCache(), sessionListCache, ws);

  Stream<String> onMessage(GlideChatMessage message);
}

class _GlideSessionInternalImpl implements GlideSessionInternal {
  GlideSessionInfo i;
  final GlideMessageCache cache;
  final SessionListCache sessionListCache;
  final GlideWsClient ws;
  final StreamController<GlideChatMessage> _messageSc =
      StreamController.broadcast();

  _GlideSessionInternalImpl(this.i, this.cache, this.sessionListCache, this.ws);

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
  Future<List> history() async {
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
      from: info.from,
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
    await ws.sendChatMessage(Action.messageGroup, cm, ticket).execute();
  }

  @override
  GlideSessionInfo get info => i;

  Future _save() async {
    await sessionListCache.updateSession(i);
  }
}
