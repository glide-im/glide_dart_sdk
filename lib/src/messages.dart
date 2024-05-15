class GlideChatMessage {
  final num mid;
  final num seq;
  final String from;
  final String to;
  final num type;
  final dynamic content;
  final num sendAt;

  GlideChatMessage({
    required this.mid,
    required this.seq,
    required this.from,
    required this.to,
    required this.type,
    required this.content,
    required this.sendAt,
  });

  factory GlideChatMessage.fromJson(Map<String, dynamic> json) {
    return GlideChatMessage(
      mid: json['mid'] ?? 0,
      seq: json['seq'] ?? 0,
      from: json['from'],
      to: json['to'],
      type: json['type'],
      content: json['content'],
      sendAt: json['sendAt'],
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
    return map;
  }
}
