import 'package:dart_sdk/api/bean.dart';
import 'package:dio/dio.dart';

abstract class JsonEntity<T> {
  Map<String, dynamic> toJson();
}

typedef DeserializeFactory<T> = T Function(Map<String, dynamic>);

typedef JsonProvideFn<T> = Map<String, dynamic> Function();

extension DeserializeFactoryExtension<T> on DeserializeFactory<T> {
  DeserializeFactory<List<T>> toListFactory() {
    return (dynamic resp) {
      if (resp is! List<Map<String, dynamic>>) {
        throw Exception(
            'invalid response data type: expected Map<String, dynamic> but got ${resp.runtimeType}');
      }
      return resp.map((e) => this(e)).toList();
    };
  }
}

class Http {
  static final Dio dio = Dio(BaseOptions(
    baseUrl: 'http://api.glide-im.pro/api/',
    connectTimeout: 5000,
    receiveTimeout: 3000,
  ));

  void addInterceptor(Interceptor interceptor) {
    dio.interceptors.add(interceptor);
  }

  void setAuthToken(String token) {
    dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    dio.options.headers.remove('Authorization');
  }

  Future<T> get<T>(String url, DeserializeFactory<T> fac) {
    return dio.get(url).then((value) {
      return fac(_resolve(value.data));
    });
  }

  Future<T> post<T>(String url, dynamic d, DeserializeFactory<T> fac) {
    Map<String, dynamic> json;
    if (d is JsonEntity) {
      json = d.toJson();
    } else if (d is Map<String, dynamic>) {
      json = d;
    } else if (d is JsonProvideFn) {
      json = d();
    } else {
      return Future.error(Exception(
          'could not convert type ${d.runtimeType} to json, please use JsonEntity or JsonProvider instead'));
    }
    return dio.post(url, data: json).then((value) {
      return fac(_resolve(value.data));
    });
  }

  dynamic _resolve(dynamic responseBody) {
    if (responseBody is! Map<String, dynamic>) {
      throw Exception('invalide response body');
    }

    var response = ResponseBean.fromJson(responseBody);
    if (response.code != 100) {
      throw Exception(response.msg);
    }
    return response.data;
  }
}
