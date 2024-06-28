import 'dart:convert';

import 'package:glide_dart_sdk/glide_dart_sdk.dart';

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

// client custom message type
enum CustomMessageType {
  stream(10011),
  typing(10020),
  unknown(-1);

  final num type;

  const CustomMessageType(this.type);

  static final _map = {
    for (var type in CustomMessageType.values) type.type: type,
  };

  static CustomMessageType valueOf(int value) =>
      _map[value] ?? CustomMessageType.unknown;
}

class CustomMessageBody {
  final CustomMessageType type;
  final dynamic data;

  CustomMessageBody({required this.type, required this.data});

  @override
  String toString() {
    return 'CustomMessageBody{type: $type, data: $data}';
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.type,
      'data': data,
    };
  }

  factory CustomMessageBody.fromMap(Map<String, dynamic> map) {
    return CustomMessageBody(
      type: CustomMessageType.valueOf(map['type']),
      data: map['data'] as dynamic,
    );
  }
}

enum FileMessageType {
  image(1),
  audio(2),
  video(3),
  document(4),
  unknown(-1);

  final int value;

  const FileMessageType(this.value);

  static final Map<num, FileMessageType> _map = {
    for (var type in FileMessageType.values) type.value: type
  };

  static FileMessageType valueOf(int value) {
    return _map[value] ?? FileMessageType.unknown;
  }
}

class FileMessageBody {
  final String name;
  final String url;
  final num size;
  final FileMessageType type;

  FileMessageBody({
    required this.name,
    required this.url,
    required this.size,
    required this.type,
  });

  @override
  String toString() {
    return 'FileMessageBody{name: $name, url: $url, size: $size, type: $type}';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'size': size,
      'type': type.value,
    };
  }

  factory FileMessageBody.fromMap(Map<String, dynamic> map) {
    return FileMessageBody(
      name: map['name'] as String,
      url: map['url'] as String,
      size: map['size'] as num,
      type: FileMessageType.valueOf(map['type']),
    );
  }
}

class Message {
  final MessageStatus status;

  final num mid;
  final num seq;
  final String from;
  final String to;
  final ChatMessageType type;
  final dynamic content;
  final num sendAt;
  final String cliMid;

  Message({
    required this.status,
    required this.mid,
    required this.seq,
    required this.from,
    required this.to,
    required this.type,
    required this.content,
    required this.sendAt,
    required this.cliMid,
  });

  factory Message.fromMap(Map<String, dynamic> json) {
    return Message.wrap(
      GlideChatMessage.fromJson(json),
      MessageStatus.received,
    );
  }

  factory Message.wrap(GlideChatMessage cm, MessageStatus status) {
    final type = ChatMessageType.of(cm.type);
    dynamic content;
    if (type.isTextBody()) {
      content = cm.content as String;
    } else {
      if (cm.content is String) {
        content = JsonDecoder().convert(cm.content as String);
      } else {
        content = cm.content;
      }
    }
    return Message(
      status: status,
      mid: cm.mid,
      seq: cm.seq,
      from: cm.from,
      to: cm.to,
      type: type,
      content: content,
      sendAt: cm.sendAt,
      cliMid: cm.cliMid,
    );
  }

  bool validate(){
    if (content is String) {
      return type.isTextBody();
    }
    return !type.isTextBody();
  }

  Message copyWith({
    MessageStatus? status,
    num? mid,
    num? seq,
    String? from,
    String? to,
    ChatMessageType? type,
    dynamic content,
    num? sendAt,
    String? cliMid,
  }) {
    return Message(
      status: status ?? this.status,
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
