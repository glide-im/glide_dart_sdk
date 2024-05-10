import 'dart:async';

import 'package:glide_dart_sdk/src/api/bean/auth_bean.dart';
import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:glide_dart_sdk/src/ws/ws_conn.dart';

import 'api/auth_api.dart';
import 'config.dart';
import 'ws/protocol.dart';
import 'ws/ws_im_client.dart';

class Glide {
  final _cli = GlideWsClient();
  dynamic _credential;
  String uid = "";

  Glide() {
    init();
  }

  void init() {
    Http.init(Configs.apiBaseUrl);
    _cli.setReconnectFunc(_connectFn);
    _cli.setAuthFunc(_authenticationFn);
  }

  void disconnect() {
    _cli.close();
  }

  Future guestLogin(String avatar, String nickname) async {
    await _login(AuthApi.loginGuest(nickname, avatar));
  }

  Future login(String account, String password) async {
    await _login(AuthApi.loginPassword(account, password));
  }

  Future _login(Future<AuthBean> api) async {
    final resp = await api;
    uid = resp.uid!.toString();
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
}
