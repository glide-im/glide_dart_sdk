import 'package:dart_sdk/im/sessions.dart';

import 'message.dart';

abstract class Session {
  final SessionList _list;

  final Map<String, Message> _messages = {};

  final String id;
  dynamic target;
  String avatar = "";
  String title = "";
  int unreadCount = 0;
  Message? lastMessage;

  Session(this._list, this.id);

  void read();

  Future<void> delete({bool reserveHistory = false});

  Future<List<Message>> getHistory({int count = 20, int offset = 0});

  void addUpdateListener(UpdateListener listener);

  void removeUpdateListener(UpdateListener listener);

  void addMessageListener(void Function(Message message) callback);

  void removeMessageListener(void Function(Message message) callback);

  void addMessage(Message message);
}

class SessionImpl extends Session {
  final List<void Function(Message)> _messageListeners = [];
  final List<UpdateListener> _updateListeners = [];

  SessionImpl(super.list, super.id);

  @override
  void read() {
    unreadCount = 0;
  }

  @override
  Future<void> delete({bool reserveHistory = false}) async {
    await _list.deleteSession(id, reserveHistory: reserveHistory);
  }

  @override
  Future<List<Message>> getHistory({int count = 20, int offset = 0}) async {
    return List.empty();
  }

  @override
  void addMessageListener(void Function(Message message) callback) {
    _messageListeners.add(callback);
  }

  @override
  void removeMessageListener(void Function(Message message) callback) {
    _messageListeners.remove(callback);
  }

  @override
  addMessage(Message message) {
    _messages[message.id] = message;
    for (var callback in _messageListeners) {
      callback(message);
    }
  }

  @override
  void removeUpdateListener(UpdateListener listener) {
    _updateListeners.remove(listener);
  }

  @override
  void addUpdateListener(UpdateListener listener) {
    _updateListeners.add(listener);
  }
}
