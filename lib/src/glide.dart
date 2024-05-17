import 'dart:async';
import 'dart:io';

import 'package:glide_dart_sdk/src/api/bean/auth_bean.dart';
import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/ws_client.dart';
import 'package:glide_dart_sdk/src/ws/ws_conn.dart';

import 'api/auth_api.dart';
import 'config.dart';
import 'session_manager.dart';
import 'ws/protocol.dart';
import 'ws/ws_im_client.dart';

enum GlideState {
  init,
  disconnected,
  connected,
  connecting;
}

class Glide {
  final tag = "Glide";
  final _cli = GlideWsClient();
  dynamic _credential;
  String _uid = "";
  late SessionManagerInternal _sessions;
  final StreamController<GlideState> _stateSc = StreamController.broadcast();
  ShouldCountUnread? shouldCountUnread;

  GlideState state = GlideState.init;

  Glide() {
    _sessions = SessionManagerInternal(_cli);
  }

  String? uid() => _uid;


  Future init() async {
    states().listen((event) {
      state = event;
    });

    Http.init(Configs.apiBaseUrl);
    await _sessions.init().toList();

    _cli.setConnectFunc(_connectFn);
    _cli.setAuthFunc(_authenticationFn);
    _cli.subscriptionState((state) {
      switch (state) {
        case WsClientState.known:
          break;
        case WsClientState.disconnected:
          _stateSc.add(GlideState.disconnected);
          break;
        case WsClientState.connecting:
          _stateSc.add(GlideState.connecting);
          break;
        case WsClientState.connected:
          break;
        case WsClientState.closing:
          break;
      }
    });
    _cli.messageStream().listen(
          (event) {
        _handleMessage(event);
      },
      onError: (e) {},
      onDone: () {},
    );
  }

  Stream<GlideState> states() => _stateSc.stream;

  SessionManager get sessionManager => _sessions;

  Future logout() async {
    _uid = "";
    _credential = null;
    await _cli.close();
  }

  static void setLogger(IOSink? sink) {
    Logger.setSink(sink);
  }

  Future tokenLogin(String token) async {
    await _login(AuthApi.loginToken(token));
  }

  Future guestLogin(String avatar, String nickname) async {
    await _login(AuthApi.loginGuest(nickname, avatar));
  }

  Future login(String account, String password) async {
    await _login(AuthApi.loginPassword(account, password));
  }

  Future _login(Future<AuthBean> api) async {
    final resp = await api;
    _uid = resp.uid!.toString();
    _credential = resp.credential!.toJson();
    Http.setToken(resp.token!);
    _sessions.setMyId(_uid);
    await _cli.request(Action.auth, _credential, needAuth: false);
    _stateSc.add(GlideState.connected);
    _cli.setAuthenticationCompleted();
  }

  Future _connectFn(WsConnection client) async {
    await client.connect(Configs.wsUrl);
  }

  Future _authenticationFn(GlideWsClient client) async {
    if (_credential == null) {
      client.close();
      throw "not authenticated yet";
    }
    try {
      final result = await client.request(
          Action.auth, _credential, needAuth: false);
    } catch (e) {
      client.close();
      throw "authenticated failed";
    }
    _stateSc.add(GlideState.connected);
    client.setAuthenticationCompleted();
  }

  void _handleMessage(ProtocolMessage message) {
    switch (message.action) {
      case Action.messageGroup:
      case Action.messageChat:
      case Action.messageGroupNotify:
        _sessions.onMessage(message, shouldCountUnread ?? (s) => true).listen((
            event) {
          Logger.info(tag, event);
        }, onError: (e) {
          Logger.err(tag, e);
        });
        break;
      case Action.kickout:
        logout().ignore();
        break;
      default:
        break;
    }
  }
}
