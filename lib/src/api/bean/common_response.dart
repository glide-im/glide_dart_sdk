class CommonResponse {
  final String msg;
  final int code;
  final dynamic data;

  CommonResponse({required this.msg, required this.code, required this.data});

  factory CommonResponse.fromJson(Map<String, dynamic> json) {
    return CommonResponse(
      msg: json['Msg'],
      code: json['Code'],
      data: json['Data'],
    );
  }
}
