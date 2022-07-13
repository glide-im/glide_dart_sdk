// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bean.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ResponseBean _$ResponseBeanFromJson(Map<String, dynamic> json) => ResponseBean(
      code: json['Code'] as int,
      msg: json['Msg'] as String? ?? '',
      data: json['Data'],
    );

Map<String, dynamic> _$ResponseBeanToJson(ResponseBean instance) =>
    <String, dynamic>{
      'Code': instance.code,
      'Msg': instance.msg,
      'Data': instance.data,
    };

LoginBean _$LoginBeanFromJson(Map<String, dynamic> json) => LoginBean(
      token: json['Token'] as String,
      nickname: json['Nickname'] as String? ?? '',
      uid: json['Uid'] as int,
      servers:
          (json['Servers'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$LoginBeanToJson(LoginBean instance) => <String, dynamic>{
      'Token': instance.token,
      'Nickname': instance.nickname,
      'Uid': instance.uid,
      'Servers': instance.servers,
    };

UserInfoBean _$UserInfoBeanFromJson(Map<String, dynamic> json) => UserInfoBean(
      uid: json['Uid'] as String,
      nickname: json['Nickname'] as String,
      avatar: json['Avatar'] as String,
    );

Map<String, dynamic> _$UserInfoBeanToJson(UserInfoBean instance) =>
    <String, dynamic>{
      'Uid': instance.uid,
      'Nickname': instance.nickname,
      'Avatar': instance.avatar,
    };
