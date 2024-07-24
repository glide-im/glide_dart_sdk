import 'dart:async';
import 'dart:convert';

import 'package:glide_dart_sdk/glide_dart_sdk.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/protocol.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/v8.dart';

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
  int onIncrementUnread(GlideSessionInfo si, Message cm);

  Message? onInterceptMessage(GlideSessionInfo si, Message cm);

  Future<GlideSessionInfo?> onSessionCreate(GlideSessionInfo si);

  Future<String?> onUpdateLastMessage(GlideSessionInfo si, Message cm);
}

class DefaultSessionEventInterceptor implements SessionEventInterceptor {
  SessionEventInterceptor? wrap;

  @override
  int onIncrementUnread(GlideSessionInfo si, Message cm) =>
      wrap?.onIncrementUnread(si, cm) ?? 0;

  @override
  Message? onInterceptMessage(
    GlideSessionInfo si,
    Message cm,
  ) =>
      wrap?.onInterceptMessage(si, cm) ?? cm;

  @override
  Future<GlideSessionInfo?> onSessionCreate(GlideSessionInfo si) =>
      wrap?.onSessionCreate(si) ?? Future.value(si);

  @override
  Future<String?> onUpdateLastMessage(GlideSessionInfo si, Message cm) =>
      wrap?.onUpdateLastMessage(si, cm) ?? Future.value(cm.content.toString());
}

abstract interface class GlideMessageCache {
  Future init(String uid);

  Future<List<Message>> getMessages(String sessionId);

  Future<void> addMessage(String sessionId, Message message);

  Future<bool> hasMessage(num mid);

  Future<Message?> getMessage(num mid);

  Future<void> removeMessage(num id);

  Future<void> updateMessage(Message message);

  Future clear();
}

class GlideMessageMemoryCache implements GlideMessageCache {
  final Map<String, List<Message>> _cache = {};
  final Map<num, String> mids = {};

  @override
  Future init(String uid) async {
    _cache.clear();
    mids.clear();
  }

  @override
  Future<void> addMessage(String sessionId, Message message) async {
    if (!_cache.containsKey(sessionId)) {
      _cache[sessionId] = [];
    }
    _cache[sessionId]?.add(message);
    mids[message.mid] = sessionId;
  }

  @override
  Future<Message?> getMessage(num mid) async {
    return mids[mid]?.isEmpty ?? false
        ? null
        : _cache[mids[mid]]?.firstWhere((element) => element.mid == mid);
  }

  @override
  Future<bool> hasMessage(num mid) async {
    return mids.containsKey(mid);
  }

  @override
  Future clear() async {
    _cache.clear();
    mids.clear();
  }

  @override
  Future<List<Message>> getMessages(String sessionId) async {
    return _cache[sessionId] ?? [];
  }

  @override
  Future<void> removeMessage(num mid) async {
    final sessionId = mids[mid];
    _cache[sessionId]?.removeWhere((element) => element.mid == mid);
  }

  @override
  Future<void> updateMessage(Message message) async {
    final sessionId = mids[message.mid]!;
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

  Future sendFileMessage(FileMessageBody body);

  // when user is tapping the keyboard, invoke this function to notify target.
  void sendTypingEvent();

  // when typing state changed, event will be emitted
  Stream<bool> onTypingChanged();

  Future recallMessage(String mid);

  Future<List<Message>> history();

  Stream<Message> messages();

  // listen to client message received
  Stream<Message> clientMessage();

  Stream<MessageEvent> messageEvent();

  Future clear();
  
  Future sendClientMessage(CustomMessageBody body);
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

  Stream<String> init();

  Stream<String> onMessage(Message message);

  Stream<String> onAck(Action action, GlideAckMessage message);

  Stream<String> onClientMessage(Message message);

  Future close();
}

class _ClientMessageEvent {
  final Message message;

  _ClientMessageEvent({required this.message});
}

enum MessageEventType {
  sent,
  received,
  recalled,
  read,
  updated;
}

class MessageEvent {
  final MessageEventType type;
  final Message message;

  MessageEvent({required this.type, required this.message});

  @override
  String toString() {
    return 'MessageEvent{type: $type, message: $message}';
  }
}

class _GlideSessionInternalImpl
    with SubscriptionManger
    implements GlideSessionInternal {
  GlideSessionInfo i;
  final Context ctx;
  int messageSequence = 1;
  bool typing = false;

  String get source => "session-${i.id}";

  final Set<String> ackAwaitMid = {};

  final StreamController<String> sendTypingEventController = StreamController();

  _GlideSessionInternalImpl(this.i, this.ctx) {
    final sp = sendTypingEventController.stream
        .throttleTime(Duration(seconds: 1))
        .listen(
      (event) {
        Logger.info(source, 'send typing event');
        _sendTypingEventInternal();
      },
      onError: (e) {
        Logger.err(source, e);
      },
    );
    addSubscription(sp);
  }

  @override
  Stream<String> init() async* {
    yield "$source initialized";
  }

  @override
  Future close() async {
    dispose();
    sendTypingEventController.close();
  }

  @override
  Stream<String> onMessage(Message message) async* {
    yield "$source message received";
    if (await ctx.messageCache.hasMessage(message.mid)) {
      await ctx.messageCache.updateMessage(message);
      yield "$source message exist";
      return;
    }
    await ctx.messageCache.addMessage(i.id, message);
    final lastMessage = await ctx.sessionEventInterceptor
        .onUpdateLastMessage(info, message);
    i = i.copyWith(
      lastMessage: lastMessage,
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
  Stream<MessageEvent> messageEvent() {
    return ctx.event.stream.mapNotNull((event) {
      return event.event is! MessageEvent ? null : event.event as MessageEvent;
    });
  }

  @override
  Stream<String> onAck(Action action, GlideAckMessage message) async* {
    final m = await ctx.messageCache.getMessage(message.mid);
    if (m == null) {
      throw "$source, message not found";
    } else {
      final status =
          (action == Action.ackNotify || info.type == SessionType.channel)
              ? MessageEventType.received
              : MessageEventType.sent;
      Message? nm;
      switch (action) {
        case Action.ackNotify:
          nm = m.copyWith(status: MessageStatus.received);
          ctx.messageCache.updateMessage(nm);
          break;
        case Action.ackMessage:
          nm = m.copyWith(status: MessageStatus.sent);
          ctx.messageCache.updateMessage(nm);
          break;
        default:
        //
      }
      if (nm != null) {
        ctx.event.add(GlobalEvent(
          source: source,
          event: MessageEvent(type: status, message: nm),
        ));
      }
      yield "$source message acked";
    }
  }

  @override
  Stream<String> onClientMessage(Message message) async* {
    ctx.event.add(GlobalEvent(
      source: source,
      event: _ClientMessageEvent(message: message),
    ));
  }

  @override
  Stream<Message> clientMessage() {
    return ctx.event.stream.mapNotNull((event) {
      final ev = event.event;
      if (event.source == source && ev is _ClientMessageEvent) {
        return ev.message;
      }
      return null;
    });
  }

  @override
  Future sendClientMessage(CustomMessageBody body) async {
    final ticket = await _ticket();
    final task = ctx.ws.send2(
      Action.messageClient,
      info.id,
      GlideChatMessage(
        mid: 0,
        seq: 0,
        cliMid: '',
        from: ctx.myId,
        to: info.to,
        type: ChatMessageType.custom.value,
        content: body.toMap(),
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
  Future<List<Message>> history() async {
    final ms = await ctx.messageCache.getMessages(i.id);
    ms.sort((a, b) => (a.sendAt - b.sendAt).toInt());
    return ms;
  }
  
  @override
  Future clear() async {
    //
  }

  @override
  Stream<Message> messages() {
    return ctx.event.stream.mapNotNull((event) {
      final ev = event.event;
      if (event.source == source && ev is Message) {
        return ev;
      }
      return null;
    });
  }

  @override
  Stream<bool> onTypingChanged() {
    return clientMessage()
        .where((event) => event.type == ChatMessageType.custom)
        .where(
          (event) =>
              CustomMessageBody.fromMap(event.content).type ==
              CustomMessageType.typing,
        )
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
  Future sendFileMessage(FileMessageBody body) async {
    await _send(ChatMessageType.file, JsonEncoder().convert(body.toMap()));
  }

  @override
  Future sendTextMessage(String content) async {
    await _send(ChatMessageType.text, content);
  }

  Future _send(ChatMessageType type, dynamic content) async {
    String rndId = UuidV8().generate();
    final gcm = GlideChatMessage(
      mid: DateTime.now().millisecondsSinceEpoch,
      seq: messageSequence,
      from: ctx.myId,
      to: info.id,
      type: type.value,
      content: content,
      sendAt: DateTime.now().millisecondsSinceEpoch,
      cliMid: rndId,
    );
    Message cm = Message.wrap(gcm, MessageStatus.unknown);
    final action = info.type == SessionType.channel
        ? Action.messageGroup
        : Action.messageChat;
    try {
      String ticket = await _ticket();
      await ctx.ws.sendChatMessage(action, gcm, ticket).execute();
    } catch (e) {
      cm = cm.copyWith(status: MessageStatus.failed);
    }
    messageSequence++;
    ctx.messageCache.addMessage(i.id, cm);
    ctx.event.add(GlobalEvent(source: source, event: cm));
    final lastMsg = await ctx.sessionEventInterceptor.onUpdateLastMessage(info, cm);
    i = i.copyWith(
      lastMessage: lastMsg,
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
    await sendClientMessage(CustomMessageBody(
      type: CustomMessageType.typing,
      data: null,
    ));
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
