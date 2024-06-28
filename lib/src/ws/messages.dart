// general message type, persistent

enum ChatMessageType {
  text(1),
  image(2),
  file(3),
  location(4),
  voice(5),
  video(6),
  markdown(11),
  custom(20),
  enter(100),
  leave(101),
  unknown(-1);

  final int value;

  bool isTextBody() {
    return this == ChatMessageType.text ||
        this == ChatMessageType.markdown ||
        this == ChatMessageType.leave ||
        this == ChatMessageType.enter ||
        this == ChatMessageType.unknown;
  }

  static final Map<num, ChatMessageType> _map = {
    for (var type in ChatMessageType.values) type.value: type
  };

  const ChatMessageType(this.value);

  static ChatMessageType of(num type) {
    return _map[type] ?? ChatMessageType.unknown;
  }
}

class GlideChatMessage {
  final num mid;
  final num seq;
  final String from;
  final String to;
  final int type;
  final dynamic content;
  final num sendAt;
  final String cliMid;

  GlideChatMessage({
    required this.mid,
    required this.seq,
    required this.from,
    required this.to,
    required this.type,
    required this.content,
    required this.sendAt,
    required this.cliMid,
  });

  factory GlideChatMessage.fromJson(Map<String, dynamic> json) {
    return GlideChatMessage(
      mid: json['mid'] ?? 0,
      seq: json['seq'] ?? 0,
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      type: json['type'] ?? 0,
      content: json['content'],
      sendAt: json['sendAt'] ?? 0,
      cliMid: json['cliMid'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['mid'] = mid;
    map['seq'] = seq;
    map['from'] = from;
    map['to'] = to;
    map['type'] = type;
    map['content'] = content;
    map['sendAt'] = sendAt;
    map['cliMid'] = cliMid;
    return map;
  }

  @override
  String toString() {
    return 'GlideChatMessage{mid: $mid, seq: $seq, from: $from, to: $to, type: $type, content: $content, sendAt: $sendAt, cliMid: $cliMid}';
  }

  GlideChatMessage copyWith({
    num? mid,
    num? seq,
    String? from,
    String? to,
    int? type,
    dynamic content,
    num? sendAt,
    String? cliMid,
  }) {
    return GlideChatMessage(
      mid: mid ?? this.mid,
      seq: seq ?? this.seq,
      from: from ?? this.from,
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
