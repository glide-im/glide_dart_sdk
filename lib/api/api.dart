import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

part 'api.g.dart';

@JsonSerializable()
class LoginBean {
  @JsonKey(name: 'account', required: false)
  final String account;
  final String password;

  LoginBean({required this.account, required this.password});

  factory LoginBean.fromJson(Map<String, dynamic> json) =>
      _$LoginBeanFromJson(json);

  Map<String, dynamic> toJson() => _$LoginBeanToJson(this);
}

class Apis {
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://api.glide-im.pro/api/',
    connectTimeout: 5000,
    receiveTimeout: 3000,
  ));

  static Future<Response<Object>> login() {
    var data = LoginBean(account: "aaa", password: "aaa");
    return _dio.post('auth/signin', data: data.toJson());
  }
}
