import 'dart:async';

import 'package:glide_dart_sdk/src/api/bean/auth_bean.dart';
import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:glide_dart_sdk/src/ws/ws_client.dart';
import 'package:glide_dart_sdk/src/ws/ws_conn.dart';

import 'api/auth_api.dart';
import 'config.dart';
import 'session_manager.dart';
import 'ws/protocol.dart';
import 'ws/ws_im_client.dart';

class Glide {
  final _cli = GlideWsClient();
  dynamic _credential;
  String _uid = "";
  final SessionManagerInternal _sessions = SessionManagerInternal();

  Glide() {
    init();
  }

  String? uid() => _uid;

  Future init() async {
    Http.init(Configs.apiBaseUrl);
    await _sessions.init().toList();

    _cli.setConnectFunc(_connectFn);
    _cli.setAuthFunc(_authenticationFn);
    _cli.subscriptionState((state) {
      switch (state) {
        case WsClientState.known:
          break;
        case WsClientState.disconnected:
          break;
        case WsClientState.connecting:
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

  SessionManager get sessionManager => _sessions;

  Future logout() async {
    _uid = "";
    _credential = null;
    await _cli.close();
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
    await _cli.request(Action.auth, _credential, needAuth: false);
  }

  Future _connectFn(WsConnection client) async {
    await client.connect(Configs.wsUrl);
  }

  Future _authenticationFn(GlideWsClient client) async {
    if (_credential == null) {
      throw "not authenticated yet";
    }
    await client.request(Action.auth, _credential, needAuth: false);
    client.setAuthenticationCompleted();
  }

  void _handleMessage(ProtocolMessage message) {
    switch (message.action) {
      case Action.messageGroup:
      case Action.messageChat:
      case Action.messageGroupNotify:
        _sessions.onMessage(message);
        break;
      case Action.kickout:
        logout().ignore();
        break;
      default:
        break;
    }
  }
}
