import 'dart:async';
import 'dart:io';

import 'package:glide_dart_sdk/src/api/apis.dart';
import 'package:glide_dart_sdk/src/api/bean/auth_bean.dart';
import 'package:glide_dart_sdk/src/api/http.dart';
import 'package:glide_dart_sdk/src/context.dart';
import 'package:glide_dart_sdk/src/errors.dart';
import 'package:glide_dart_sdk/src/session.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';
import 'package:glide_dart_sdk/src/ws/ws_client.dart';
import 'package:glide_dart_sdk/src/ws/ws_conn.dart';

import 'config.dart';
import 'messages.dart';
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
  late Context _context;
  late SessionManagerInternal _sessions;

  final StreamController<GlideState> _stateSc = StreamController.broadcast();
  ShouldCountUnread? shouldCountUnread;
  final GlideApi api = GlideApi();

  GlideState state = GlideState.init;

  Glide() {
    _context = Context(
      api: api,
      ws: _cli,
      sessionCache: SessionListMemoryCache(),
      messageCache: GlideMessageMemoryCache(),
      myId: "",
    );
    _sessions = SessionManagerInternal(_context);
  }

  String? uid() => _context.myId;

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
    _context.myId = "";
    _credential = null;
    await _cli.close();
  }

  static void setLogger(IOSink? sink) {
    Logger.setSink(sink);
  }

  Future<AuthBean> tokenLogin(String token) async {
    return await _login(api.auth.loginToken(token));
  }

  Future<AuthBean> guestLogin(String avatar, String nickname) async {
    return await _login(api.auth.loginGuest(nickname, avatar));
  }

  Future<AuthBean> login(String account, String password) async {
    return await _login(api.auth.loginPassword(account, password));
  }

  Future<AuthBean> _login(Future<AuthBean> api) async {
    final resp = await api;
    _context.myId = resp.uid!.toString();
    _credential = resp.credential!.toJson();
    Http.setToken(resp.token!);
    await _cli.request(Action.auth, _credential, needAuth: false);
    _stateSc.add(GlideState.connected);
    _cli.setAuthenticationCompleted();
    return resp;
  }

  Future _connectFn(WsConnection client) async {
    await client.connect(Configs.wsUrl);
  }

  Future _authenticationFn(GlideWsClient client) async {
    if (_credential == null) {
      client.close();
      throw GlideException.unauthorized;
    }
    try {
      await client.request(Action.auth, _credential, needAuth: false);
    } catch (e) {
      client.close();
      throw GlideException.authorizeFailed;
    }
    _stateSc.add(GlideState.connected);
    client.setAuthenticationCompleted();
  }

  void _handleMessage(ProtocolMessage message) {
    switch (message.action) {
      case Action.messageGroup:
      case Action.messageChat:
      case Action.messageGroupNotify:
        _sessions.onMessage(message, _shouldCountUnread).listen(
          (event) {
            Logger.info(tag, "[message-${message.hashCode}] $event");
          },
          onError: (e) {
            Logger.err(tag, e);
          },
          onDone: () {
            Logger.info(tag, "[message-${message.hashCode}] handled done");
          },
        );
        break;
      case Action.kickout:
        logout().ignore();
        break;
      default:
        break;
    }
  }

  bool _shouldCountUnread(
      GlideSessionInfo sessionInfo, GlideChatMessage message) {
    if (shouldCountUnread != null) {
      return shouldCountUnread!.call(sessionInfo, message);
    }
    return true;
  }
}
