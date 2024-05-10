import 'dart:async';
import 'dart:convert';

import 'package:glide_dart_sdk/src/ws/ws_client.dart';
import 'package:glide_dart_sdk/src/ws/ws_conn.dart';

import 'message_task.dart';
import 'protocol.dart';

class GlideWsClient extends WsClientImpl {
  final Map<num, StreamController<ProtocolMessage>> _msgWaitSc =
      <num, StreamController<ProtocolMessage>>{};
  final StreamController<ProtocolMessage> _messageSc =
      StreamController.broadcast();
  late StreamSubscription _messageSubscription;
  num _seq = 0;

  GlideWsClient() : super(WsConnection()) {
    _messageSubscription = subscribeMessage((message) => _onReceive(message));
  }

  @override
  Future close({bool discardMessages = false, bool reconnect = false}) async {
    super.close(discardMessages: discardMessages, reconnect: reconnect);
    _messageSubscription.cancel();
    _messageSc.close();
  }

  Stream<ProtocolMessage> messageStream() {
    return _messageSc.stream;
  }

  Future<T> request<T>(Action action, dynamic data,
      {bool needAuth = true}) async {
    final seq = --_seq;
    final m = ProtocolMessage(action: action.action, data: data, seq: seq);
    final task = send<ProtocolMessage>(m.toJson(),
        needAuth: needAuth, awaitConnect: true);
    _setupMessageTask(seq, task, Duration(seconds: 2));
    final resp = await task.execute();
    if (resp.action == Action.notifyError.action) {
      throw resp.data;
    }
    if (resp.action != Action.notifySuccess.action) {
      throw "unknown action: ${resp.action}";
    }
    return resp.data as T;
  }

  @override
  void setAuthFunc(Future Function(GlideWsClient c)? authFn) {
    if (authFn == null) {
      super.setAuthFunc(null);
      return;
    }
    super.setAuthFunc((c) async {
      await authFn(this);
    });
  }

  @override
  MessageTask<T> send<T>(msg,
      {serializeToJson = true,
      bool awaitConnect = false,
      bool needAuth = false}) {
    final task = super.send<T>(msg,
        serializeToJson: serializeToJson,
        awaitConnect: awaitConnect,
        needAuth: needAuth);
    return task;
  }

  void _onReceive(dynamic message) {
    final json = JsonDecoder().convert(message);
    final msg = ProtocolMessage.fromJson(json);
    final sc = _msgWaitSc[msg.seq];
    if (sc != null) {
      sc.add(msg);
    } else {
      _messageSc.add(msg);
    }
  }

  void _setupMessageTask(num seq, MessageTask sendTask, Duration timeout) {
    final sc = StreamController<ProtocolMessage>();
    sendTask.addStep((_) async {
      final response = await sc.stream.first.timeout(timeout);
      return response;
    });

    sendTask.onExecute(() => _msgWaitSc[seq] = sc);
    sendTask.onCancel(() {
      _msgWaitSc.remove(seq);
      sc.close().ignore();
    });
    sendTask.onComplete(() {
      _msgWaitSc.remove(seq);
      sc.close().ignore();
    });
  }
}
