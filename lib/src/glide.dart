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
import 'package:rxdart/rxdart.dart';

import 'config.dart';
import 'session_manager.dart';
import 'ws/messages.dart';
import 'ws/protocol.dart';
import 'ws/ws_im_client.dart';

enum GlideState {
  init,
  disconnected,
  connected,
  connecting;
}

abstract class GlideEventListener {
  void onCacheLoaded();
}

class Glide {
  final tag = "Glide";
  final _cli = GlideWsClient();
  String _token = "";
  late Context _context;
  late SessionManagerInternal _sessions;
  final _interceptor = DefaultSessionEventInterceptor();

  final StreamController<GlideState> _stateSc = StreamController.broadcast();
  final GlideApi api = GlideApi();
  GlideEventListener? _listener;

  GlideState state = GlideState.init;

  Glide() {
    _context = Context(
      api: api,
      ws: _cli,
      sessionCache: SessionListMemoryCache(),
      messageCache: GlideMessageMemoryCache(),
      myId: "",
      sessionEventInterceptor: _interceptor,
    );
    _sessions = SessionManagerInternal(_context);
  }

  void setSessionCache(SessionListCache c) {
    _context.sessionCache = c;
  }

  void setMessageCache(GlideMessageCache c) {
    _context.messageCache = c;
  }

  void setEventListener(GlideEventListener? listener) {
    _listener = listener;
  }

  void setSessionEventInterceptor(SessionEventInterceptor interceptor) {
    _interceptor.wrap = interceptor;
  }

  String? uid() => _context.myId;

  Stream<String> init() async* {
    yield "$tag start init";
    states().listen((event) {
      state = event;
    });

    Http.init(Configs.apiBaseUrl);
    _cli.setConnectFunc(_connectFn);
    _cli.setAuthFunc(_authenticationFn);
    _cli.subscriptionState((state) {
      Logger.info(tag, "ws client state changed: $state");
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

    yield "$tag init done";
  }

  Stream<GlideState> states() => _stateSc.stream;

  Stream<Message> messageStream() =>
      _context.event.stream.mapNotNull((event) {
        return event.event is Message ? event.event : null;
      });

  SessionManager get sessionManager => _sessions;


  Future logout() async {
    _context.myId = "";
    if (state == GlideState.connected) {
      await _cli.close();
    }
  }

  static void setLogger(IOSink? sink) {
    Logger.setSink(sink);
  }

  Future<AuthBean> tokenLogin(String token) async {
    return await _startAuth(api.auth.loginToken(token));
  }

  Future<AuthBean> guestLogin(String nickname, String avatar) async {
    return await _startAuth(api.auth.loginGuest(nickname, avatar));
  }

  Future<AuthBean> login(String account, String password) async {
    return await _startAuth(api.auth.loginPassword(account, password));
  }

  Future<AuthBean> _startAuth(Future<AuthBean> api) async {
    final resp = await api;
    _context.myId = resp.uid!.toString();
    _token = resp.token!;
    final credential = resp.credential!.toJson();
    Http.setToken(resp.token!);

    Logger.info(tag, "init account cache, ${_context.sessionCache}, ${_context
        .messageCache}");
    await _context.sessionCache.init(_context.myId).timeout(
        const Duration(seconds: 5));
    await _context.messageCache.init(_context.myId).timeout(
        const Duration(seconds: 5));

    await _sessions.init().forEach((event) {
      Logger.info(tag, "session manager: $event");
    }).timeout(const Duration(seconds: 5));

    _listener?.onCacheLoaded();

    Logger.info(tag, "authentication websocket");
    await _cli.request(Action.auth, credential, needAuth: false);
    _stateSc.add(GlideState.connected);
    _cli.setAuthenticationCompleted();

    Logger.info(tag, "login done");
    return resp;
  }

  Future _connectFn(WsConnection client) async {
    await client.connect(Configs.wsUrl);
  }

  Future _authenticationFn(GlideWsClient client) async {
    if (_token.isEmpty) {
      client.close();
      throw GlideException.unauthorized;
    }
    try {
      final bean = await api.auth.loginToken(_token);
      await client.request(Action.auth, bean.credential!.toJson(), needAuth: false);
    } catch (e) {
      client.close();
      throw GlideException.authorizeFailed;
    }
    _stateSc.add(GlideState.connected);
    client.setAuthenticationCompleted();
  }

  void _handleMessage(ProtocolMessage message) {
    switch (message.action) {
      case Action.messageChat:
      case Action.messageGroup:
      case Action.messageGroupNotify:
        Message cm = Message.recv(message.data);
        _sessions.onMessage(message.action, cm).timeout(
            const Duration(seconds: 3)).listen(
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
      case Action.messageClient:
        Message cm = Message.recv(message.data);
        _sessions.onClientMessage(message.action, cm).timeout(
            const Duration(seconds: 3)).listen(
              (event) {
            Logger.info(tag, "[cli-message-${message.hashCode}] $event");
          },
          onError: (e) {
            Logger.err(tag, e);
          },
        );
        break;
      case Action.ackNotify:
      case Action.ackMessage:
        final ack = GlideAckMessage.fromMap(message.data);
        _sessions.onAck(message.action, ack)
            .timeout(const Duration(seconds: 3))
            .listen((event) {
          //
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
