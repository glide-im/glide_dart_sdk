import 'package:glide_dart_sdk/src/api/auth_api.dart';
import 'package:glide_dart_sdk/src/api/session_api.dart';
import 'package:glide_dart_sdk/src/api/user_api.dart';

class GlideApi {
  final AuthApi auth = const AuthApi();
  final SessionApi session = const SessionApi();
  final UserApi user = const UserApi();
}
