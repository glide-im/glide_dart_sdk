enum Action {
  hello("hello"),
  auth("authenticate"),
  ackRequest("ack.request"),
  ackNotify("ack.notify"),
  messageChat("message.chat"),
  messageGroup("message.group"),
  messageGroupNotify("message.group.notify"),
  notifySuccess("notify.success"),
  notifyError("notify.error"),
  heartbeat("heartbeat");

  final String action;

  const Action(this.action);
}

class ProtocolMessage<T> {
  final num ver;
  final String action;
  final T data;
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

  factory ProtocolMessage.fromJson(dynamic json) {
    return ProtocolMessage(
      ver: json['ver'],
      action: json['action'],
      data: json['data'],
      seq: json['seq'],
      to: json['to'],
      ticket:  json['ticket'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ver': ver,
      'action': action,
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
