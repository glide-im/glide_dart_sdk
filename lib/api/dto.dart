import 'package:dart_sdk/api/http.dart';
import 'package:json_annotation/json_annotation.dart';

part 'dto.g.dart';

@JsonSerializable()
class LoginDto extends JsonEntity<LoginDto> {
  final String account;
  final String password;
  LoginDto({required this.account, required this.password});

  factory LoginDto.fromJson(Map<String, dynamic> json) =>
      _$LoginDtoFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$LoginDtoToJson(this);
}
