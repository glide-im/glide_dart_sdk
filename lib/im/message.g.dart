// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
      id: json['Id'] as String,
      from: json['From'] as String,
      to: json['To'] as String,
      content: json['Content'] as String,
      type: json['Type'] as int,
      sendAt: json['SendAt'] as int,
    );

Map<String, dynamic> _$MessageToJson(Message instance) => <String, dynamic>{
      'Id': instance.id,
      'From': instance.from,
      'To': instance.to,
      'Content': instance.content,
      'Type': instance.type,
      'SendAt': instance.sendAt,
    };

CommonMessage _$CommonMessageFromJson(Map<String, dynamic> json) =>
    CommonMessage()
      ..action = json['Action'] as String
      ..from = json['From'] as String
      ..to = json['To'] as String
      ..seq = json['Seq'] as int
      ..data = json['Data']
      ..extra = json['Extra'] as Map<String, dynamic>?;

Map<String, dynamic> _$CommonMessageToJson(CommonMessage instance) =>
    <String, dynamic>{
      'Action': instance.action,
      'From': instance.from,
      'To': instance.to,
      'Seq': instance.seq,
      'Data': instance.data,
      'Extra': instance.extra,
    };
