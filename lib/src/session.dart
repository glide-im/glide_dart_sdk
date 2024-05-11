import 'dart:async';

import 'messages.dart';

class GlideSessionInfo {
  final String id;
  final String ticket;
  final String to;
  final String title;
  final num createAt;
  final num updateAt;
  final num lastReadAt;
  final num lastReadSeq;

  GlideSessionInfo({
    required this.id,
    required this.ticket,
    required this.to,
    required this.title,
    required this.createAt,
    required this.updateAt,
    required this.lastReadAt,
    required this.lastReadSeq,
  });

  factory GlideSessionInfo.create2(String to) {
    return GlideSessionInfo.create(to, to);
  }

  factory GlideSessionInfo.create(String to, String title) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return GlideSessionInfo(
      id: to,
      ticket: "",
      to: to,
      title: title,
      createAt: now,
      updateAt: now,
      lastReadAt: now,
      lastReadSeq: 0,
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

  dynamic sendTextMessage(String content);

  void onTypingEvent();

  Future<List<dynamic>> history();

  Stream<GlideChatMessage> messages();
}

abstract interface class GlideSessionInternal extends GlideSession {
  factory GlideSessionInternal(String to) =>
      GlideSessionInternal.create(GlideSessionInfo.create2(to));

  factory GlideSessionInternal.create(GlideSessionInfo info) =>
      _GlideSessionInternalImpl(info, GlideMessageMemoryCache());

  Future onMessage(GlideChatMessage message);
}

class _GlideSessionInternalImpl implements GlideSessionInternal {
  final GlideSessionInfo i;
  final GlideMessageCache cache;
  final StreamController<GlideChatMessage> _messageSc =
      StreamController.broadcast();

  _GlideSessionInternalImpl(this.i, this.cache);

  @override
  Future onMessage(GlideChatMessage message) async {
    cache.addMessage(i.id, message);
  }

  @override
  Future clearUnread() {
    // TODO: implement clearUnread
    throw UnimplementedError();
  }

  @override
  Future<List> history() async {
    return cache.getMessages(i.id);
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
  sendTextMessage(String content) {
    // TODO: implement sendTextMessage
    throw UnimplementedError();
  }

  @override
  GlideSessionInfo get info => i;
}
