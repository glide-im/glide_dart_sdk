// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginBean _$LoginBeanFromJson(Map<String, dynamic> json) => LoginBean(
      account: json['account'] as String,
      password: json['password'] as String,
    );

Map<String, dynamic> _$LoginBeanToJson(LoginBean instance) => <String, dynamic>{
      'account': instance.account,
      'password': instance.password,
    };
