import 'package:dio/dio.dart';

class _http {
  static final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://api.glide-im.pro/api/',
    connectTimeout: 5000,
    receiveTimeout: 3000,
  ));

  Future<Response<T>> post<T>(String url, Map<String, dynamic> data) {
    return dio.post(url, data: data);
  }
}
