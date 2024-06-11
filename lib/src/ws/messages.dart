class GlideChatMessage {
  final num mid;
  final num seq;
  final String from;
  final String to;
  final num type;
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
      type: json['type'],
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
