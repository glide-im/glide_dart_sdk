import 'dart:ffi';

import 'package:json_annotation/json_annotation.dart';

part 'bean.g.dart';

@JsonSerializable()
class ResponseBean {
  final int code;
  @JsonKey(required: false, defaultValue: "")
  final String msg;
  final dynamic data;
  ResponseBean({required this.code, required this.msg, required this.data});

  factory ResponseBean.fromJson(Map<String, dynamic> json) =>
      _$ResponseBeanFromJson(json);
}

@JsonSerializable()
class LoginBean {
  final String token;
  @JsonKey(required: false, defaultValue: "")
  final String nickname;
  final int uid;
  final List<String> servers;

  LoginBean(
      {required this.token,
      required this.nickname,
      required this.uid,
      required this.servers});

  factory LoginBean.fromJson(Map<String, dynamic> json) =>
      _$LoginBeanFromJson(json);
}

@JsonSerializable()
class UserInfoBean {
  final String uid;
  final String nickname;
  final String avatar;

  UserInfoBean(
      {required this.uid, required this.nickname, required this.avatar});

  factory UserInfoBean.fromJson(Map<String, dynamic> json) =>
      _$UserInfoBeanFromJson(json);
}
