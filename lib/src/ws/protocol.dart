import 'package:glide_dart_sdk/glide_dart_sdk.dart';

enum Action {
  hello("hello"),
  auth("authenticate"),
  ackRequest("ack.request"),
  ackNotify("ack.notify"),
  ackMessage("ack.message"),
  messageChat("message.chat"),
  messageGroup("message.group"),
  messageGroupNotify("message.group.notify"),
  messageClient("message.cli"),
  notifySuccess("notify.success"),
  notifyError("notify.error"),
  heartbeat("heartbeat"),
  kickout("kickout"),
  unknown("unknown");

  final String action;

  static final Map<String, Action> _map = {
    for (var action in Action.values) action.action: action
  };

  const Action(this.action);

  static Action of(String? action) {
    return _map[action] ?? Action.unknown;
  }
}

// client custom message type
enum ClientMessageType {
  stream(10011),
  typing(10020);

  final num type;

  const ClientMessageType(this.type);
}

// general message type, persistent
enum ChatMessageType {
  text(1),
  image(2),
  file(3),
  location(4),
  voice(5),
  video(6),
  unknown(1);

  final num type;

  const ChatMessageType(this.type);
}

class ProtocolMessage {
  final num ver;
  final Action action;
  final dynamic data;
  final num? seq;
  final String? to;
  final String? ticket;

  ProtocolMessage({
    required this.action,
    required this.data,
    this.ver = 1,
    this.seq,
    this.to,
    this.ticket,
  });

  factory ProtocolMessage.ackRequest(GlideAckMessage message) {
    return ProtocolMessage(
      action: Action.ackRequest,
      data: message.toMap(),
      to: message.to,
    );
  }

  factory ProtocolMessage.fromJson(dynamic json) {
    return ProtocolMessage(
      ver: json['ver'],
      action: Action.of(json['action']),
      data: json['data'],
      seq: json['seq'],
      to: json['to'],
      ticket: json['ticket'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ver': ver,
      'action': action.action,
      'data': data,
      'seq': seq,
      'to': to,
      'ticket': ticket,
    };
  }
}

class GlideAuthMessage {
  final String credential;
  final num version;

  GlideAuthMessage({required this.credential, required this.version});

  Map<String, dynamic> toJson() {
    return {
      'credential': credential,
      'version': version,
    };
  }
}
