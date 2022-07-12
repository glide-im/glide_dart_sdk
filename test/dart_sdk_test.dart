import 'package:dart_sdk/api/api.dart';
import 'package:dart_sdk/dart_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('calculate', () {
    expect(calculate(), 42);
  });

  test('api_login', () async {
    var response = await Apis.login();
    print(response);
  });
}
