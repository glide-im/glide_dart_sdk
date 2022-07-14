import 'package:dart_sdk/api/api.dart';
import 'package:dart_sdk/api/dto.dart';
import 'package:test/test.dart';

void main() {

  test('api.login success', () async {
    final loginBean =
        await Apis.login(LoginDto(account: "aaa", password: "aaa"));

    Apis.login(LoginDto(account: "aaa", password: "aaa")).then((value) {
      expect(value.token, isNotNull);
    });
    expect(loginBean.token, isNotEmpty);
  });

  test('api.login incorrect password', () async {
    try {
      await Apis.login(LoginDto(account: "aaa", password: "bbb"));
      fail('should throw exception');
    } catch (e) {
      expect(e.toString(), contains('password'));
    }
  });
}
