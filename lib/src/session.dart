import 'dart:async';

import 'package:glide_dart_sdk/glide_dart_sdk.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:rxdart/rxdart.dart';

import 'context.dart';

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
    assert(to.isNotEmpty);
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

abstract class SessionEventInterceptor {
  int onIncrementUnread(GlideSessionInfo si, GlideChatMessage cm);

  GlideChatMessage? onInterceptMessage(
      GlideSessionInfo si, GlideChatMessage cm);

  GlideSessionInfo? onSessionCreate(GlideSessionInfo si);
}

class DefaultSessionEventInterceptor implements SessionEventInterceptor {
  SessionEventInterceptor? wrap;

  @override
  int onIncrementUnread(GlideSessionInfo si, GlideChatMessage cm) =>
      wrap?.onIncrementUnread(si, cm) ?? 0;

  @override
  GlideChatMessage? onInterceptMessage(
    GlideSessionInfo si,
    GlideChatMessage cm,
  ) =>
      wrap?.onInterceptMessage(si, cm) ?? cm;

  @override
  GlideSessionInfo? onSessionCreate(GlideSessionInfo si) =>
      wrap?.onSessionCreate(si) ?? si;
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

  Future<void> updateInfo(GlideSessionInfo info);

  Future clearUnread();

  Future addUnread(int count);

  Future sendTextMessage(String content);

  // when user is tapping the keyboard, invoke this function to notify target.
  void sendTypingEvent();

  // when typing state changed, event will be emitted
  Stream<bool> onTypingChanged();

  Future recallMessage(String mid);

  Future<List<GlideChatMessage>> history();

  Stream<GlideChatMessage> messages();

  // listen to client message received
  Stream<GlideChatMessage> clientMessage();

  Future sendClientMessage(num type, dynamic message);
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

  void onAck(Action action, GlideAckMessage message);

  Stream<String> onClientMessage(GlideChatMessage message);
}

class _AckEvent {
  final Action action;
  final GlideAckMessage message;

  _AckEvent({required this.action, required this.message});
}

class _ClientMessageEvent {
  final GlideChatMessage message;

  _ClientMessageEvent({required this.message});
}

class _GlideSessionInternalImpl implements GlideSessionInternal {
  GlideSessionInfo i;
  final Context ctx;
  int messageSequence = 1;
  bool typing = false;

  String get source => "session-${i.id}";

  static final StreamController<_AckEvent> ackEvents =
      StreamController.broadcast();

  final StreamController<String> sendTypingEventController = StreamController();

  _GlideSessionInternalImpl(this.i, this.ctx) {
    sendTypingEventController.stream.throttleTime(Duration(seconds: 1)).listen(
      (event) {
        Logger.info(source, 'send typing event');
        _sendTypingEventInternal();
      },
      onError: (e) {
        Logger.err(source, e);
      },
    );
  }

  @override
  Stream<String> onMessage(GlideChatMessage message) async* {
    yield "$source message received";
    if (await ctx.messageCache.hasMessage(message.mid)) {
      await ctx.messageCache.updateMessage(i.id, message);
      yield "$source message exist";
      return;
    }
    await ctx.messageCache.addMessage(i.id, message);
    i = i.copyWith(
      lastMessage: message.content.toString(),
      updateAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _save();
    yield "$source message saved";
    ctx.event.add(GlobalEvent(source: source, event: message));
    yield "$source update notified";
  }

  @override
  Future<void> updateInfo(GlideSessionInfo info) async {
    // those fields are not allowed to be updated
    assert(i.id == info.id && i.to == info.to && i.type == info.type);
    i = info;
    await _save();
  }

  @override
  void onAck(Action action, GlideAckMessage message) {
    ackEvents.add(_AckEvent(action: action, message: message));
  }

  @override
  Stream<String> onClientMessage(GlideChatMessage message) async* {
    ctx.event.add(GlobalEvent(
      source: source,
      event: _ClientMessageEvent(message: message),
    ));
  }

  @override
  Stream<GlideChatMessage> clientMessage() {
    return ctx.event.stream.mapNotNull((event) {
      final ev = event.event;
      if (event.source == source && ev is _ClientMessageEvent) {
        return ev.message;
      }
      return null;
    });
  }

  @override
  Future sendClientMessage(num type, dynamic message) async {
    final ticket = await _ticket();
    final task = ctx.ws.send2(
      Action.messageClient,
      info.id,
      GlideChatMessage(
        mid: 0,
        seq: 0,
        from: ctx.myId,
        to: info.to,
        type: type,
        content: message,
        sendAt: DateTime.now().millisecondsSinceEpoch,
      ).toJson(),
      ticket,
    );
    await task.execute();
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
  Stream<bool> onTypingChanged() {
    return clientMessage()
        .where((event) => event.type == ClientMessageType.typing.type)
        .map((event) => true)
        .timeout(Duration(seconds: 2))
        .onErrorReturn(false)
        .distinct((p, n) => p == n);
  }

  @override
  void sendTypingEvent() async {
    sendTypingEventController.add("");
  }

  @override
  Future sendTextMessage(String content) async {
    final cm = GlideChatMessage(
      mid: DateTime.now().millisecondsSinceEpoch,
      seq: messageSequence,
      from: ctx.myId,
      to: info.id,
      type: ChatMessageType.text.type,
      content: content,
      sendAt: DateTime.now().millisecondsSinceEpoch,
    );
    String ticket = await _ticket();
    final action = info.type == SessionType.channel
        ? Action.messageGroup
        : Action.messageChat;
    await ctx.ws.sendChatMessage(action, cm, ticket).execute();
    messageSequence++;
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

  Future<String> _ticket() async {
    String ticket = info.ticket;
    if (ticket.isEmpty) {
      final bean = await ctx.api.session.getTicket(info.to);
      ticket = bean.ticket;
      updateInfo(info.copyWith(ticket: ticket));
    }
    return ticket;
  }

  Future _sendTypingEventInternal() async {
    if (info.type != SessionType.chat) {
      throw "$source not chat";
    }
    await sendClientMessage(ClientMessageType.typing.type, {});
  }

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
