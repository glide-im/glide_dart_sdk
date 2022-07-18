import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

enum Action {
  none(action: ""),

  // chat
  messageChat(action: "message.chat"),
  messageChatResend(action: "message.chat.resend"),
  messageGroupChat(action: "message.group"),
  messageFailed(action: "message.failed.send"),

  // ack
  ack(action: "ack.message"),
  ackNotify(action: "ack.notify"),
  ackRequest(action: "ack.request"),

  // control
  apiAuth(action: "api.auth"),
  heartbeat(action: "heartbeat"),

  // notify
  notifyUnknownAction(action: "notify.unknown.action"),
  notifyKickout(action: "notify.kickout"),
  notifyNewContact(action: "notify.contact"),
  notifyError(action: "notify.error"),
  hello(action: "hello"),
  notify(action: "notify");

  final String action;

  const Action({required this.action});
}

@JsonSerializable()
class Message {
  String id = "";
  String from = "";
  String to = "";
  String content = "";
  int type = 0;
  int sendAt = 0;

  Message({
    required this.id,
    required this.from,
    required this.to,
    required this.content,
    required this.type,
    required this.sendAt,
  });
}

@JsonSerializable()
class CommonMessage {
  String action = "";
  String from = "";
  String to = "";
  int seq = 0;

  dynamic data;
  Map<String, dynamic>? extra;
}
