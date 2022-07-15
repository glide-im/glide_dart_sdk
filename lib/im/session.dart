import 'package:dart_sdk/im/sessions.dart';

import 'message.dart';

abstract class Session {
  final SessionList _list;

  final String id;
  dynamic target;
  String avatar = "";
  String title = "";
  int unreadCount = 0;
  Message? lastMessage;

  Session(this._list, this.id);

  Future<void> read();

  Future<void> delete({bool reserveHistory = false});

  Future<List<Message>> getHistory({int count = 20, int offset = 0});

  _addMessage(Message message);
}
