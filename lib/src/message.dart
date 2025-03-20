// general message type, persistent

import 'dart:convert';

import 'package:glide_dart_sdk/src/ws/protocol.dart';

part 'message_type.dart';

abstract class MessageType<T> {
  final int type;
  final String name;

  final bool isUserMessage;

  static final Map<int, MessageType> _subTypes = {};

  static MessageType? typeOf(num type) => _subTypes[type];

  static void register(MessageType type) {
    _subTypes[type.type] = type;
  }

  MessageType({required this.type, required this.name, this.isUserMessage = true});

  String contentDescription(T data) => data.toString();

  T decode(dynamic data) => data as T;

  dynamic encode(T data) => data;
}

enum MessageStatus {
  pending(1),
  sent(2),
  received(3),
  read(4),
  failed(5),
  unknown(6);

  final int value;

  static final Map<int, MessageStatus> _map = {
    for (var status in MessageStatus.values) status.value: status,
  };

  const MessageStatus(this.value);

  static MessageStatus valueOf(int value) {
    return _map[value] ?? MessageStatus.sent;
  }
}

class Message<T> {
  final num mid;
  final num seq;
  final String from;
  final String to;
  final MessageStatus status;
  final MessageType<T> type;
  final T content;
  final num sendAt;
  final String cliMid;

  Message({
    required this.mid,
    required this.seq,
    required this.from,
    required this.to,
    required this.type,
    required this.content,
    required this.sendAt,
    required this.cliMid,
    this.status = MessageStatus.unknown,
  });

  factory Message.decode(ProtocolMessage raw) {
    dynamic json = raw.data;
    int? t = json['type'] as int;
    MessageType? type = MessageType.typeOf(t) ?? UnknownMessageType(t);
    T content = type.decode(json['content'] ?? json['body']);
    var msg = Message(
      mid: json['mid'] ?? 0,
      seq: json['seq'] ?? 0,
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      type: type as MessageType<T>,
      status: MessageStatus.unknown,
      content: content,
      sendAt: json['sendAt'] ?? 0,
      cliMid: json['cliMid'] ?? '',
    );
    if (msg.to == '') {
      msg = msg.copyWith(to: raw.to);
    }
    return msg;
  }

  bool validate() => true;

  dynamic encodeBody() {
    return type.encode(content);
  }

  dynamic decodeBody(dynamic data) {
    return type.decode(data);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['mid'] = mid;
    map['seq'] = seq;
    map['from'] = from;
    map['to'] = to;
    map['type'] = type.type;
    map['content'] = type.encode(content);
    map['sendAt'] = sendAt;
    map['cliMid'] = cliMid;
    return map;
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Message<T> copyWith({
    num? mid,
    num? seq,
    String? from,
    String? to,
    MessageType<T>? type,
    T? content,
    num? sendAt,
    MessageStatus? status,
    String? cliMid,
  }) {
    return Message<T>(
      mid: mid ?? this.mid,
      seq: seq ?? this.seq,
      from: from ?? this.from,
      status: status ?? this.status,
      to: to ?? this.to,
      type: type ?? this.type,
      content: content ?? this.content,
      sendAt: sendAt ?? this.sendAt,
      cliMid: cliMid ?? this.cliMid,
    );
  }
}

class GlideAckMessage {
  final num mid;
  final String from;
  final String to;
  final String cliMid;
  final num seq;

  GlideAckMessage({
    required this.mid,
    required this.from,
    required this.to,
    required this.cliMid,
    required this.seq,
  });

  Map<String, dynamic> toMap() {
    return {
      'mid': mid,
      'from': from,
      'cliMid': cliMid,
      'seq': seq,
      'to': to,
    };
  }

  factory GlideAckMessage.fromMap(Map<String, dynamic> map) {
    return GlideAckMessage(
      mid: map['mid'] ?? 0,
      from: map['from'] ?? '',
      to: map['to'] ?? '',
      cliMid: map['cliMid'] ?? '',
      seq: map['seq'] ?? 0,
    );
  }
}
