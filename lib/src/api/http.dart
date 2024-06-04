import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:glide_dart_sdk/src/utils/logger.dart';

import 'bean/common_response.dart';

typedef JsonFactory<T> = T Function(dynamic json);

class ListFactory<T> {
  final JsonFactory<T> factory;

  ListFactory(this.factory);

  List<T> call(dynamic list) {
    assert(list is List);
    List<T> result = [];
    for (var e in list) {
      result.add(factory(e));
    }
    return result;
  }
}

class ApiException implements Exception {
  final String message;
  final int code;

  ApiException(this.message, this.code);

  @override
  String toString() {
    return 'ApiException{message: $message, code: $code}';
  }

  factory ApiException.wrap(dynamic exception) {
    if (exception is ApiException) {
      return exception;
    }
    String msg = "";
    if (exception is DioException) {
      switch (exception.type) {
        case DioExceptionType.connectionTimeout:
          msg = "Connection timeout";
          break;
        case DioExceptionType.receiveTimeout:
          msg = "Response timeout";
          break;
        case DioExceptionType.sendTimeout:
          msg = "Request timeout";
          break;
        case DioExceptionType.cancel:
          msg = "Request cancelled";
          break;
        case DioExceptionType.badResponse:
          msg =
              "Bad response, ${exception.response?.statusCode ?? 0} ${exception.response?.statusMessage ?? ""}";
          break;
        case DioExceptionType.unknown:
          msg = "Network error";
          break;
        case DioExceptionType.badCertificate:
          msg = "Bad certificate";
          break;
        case DioExceptionType.connectionError:
          msg = "Connection error";
          break;
      }
      if (msg.isNotEmpty) {
        return ApiException(msg, -1);
      }

      final resp = exception.response;
      if (resp != null) {
        msg = "${exception.message}";
        return ApiException(msg, resp.statusCode ?? -1);
      }
    }
    if (exception is FormatException) {
      return ApiException("Response parse failed, ${exception.message}", -2);
    }
    return ApiException(exception.toString(), -1);
  }
}

class Http {
  static const String tag = "Http";
  static const String _baseUrl = "";

  static final dio = Dio();
  static final Map<String, dynamic> _header = {
    'Authorization': "",
  };

  static void setToken(String token) {
    _header["Authorization"] = token;
    dio.options.headers = _header;
    Logger.debug(tag, 'set token: $token');
  }

  static void init(String host) {
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.baseUrl = host;
    Logger.debug(tag, 'base url: ${dio.options.baseUrl}');
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!options.path.startsWith(_baseUrl)) {
          options.headers = {};
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioError e, handler) {
        Logger.err(tag, "error ${e.message}");
        return handler.next(e);
      },
    ));
  }

  static Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    JsonFactory<T>? factory,
    bool? resolve,
  }) async {
    final q = query == null ? "" : "query=$query";
    String p = _path(path);
    final r = "get $p";
    Logger.debug(tag, ">>>> $p $q");
    final response = await dio
        .get(p, queryParameters: query)
        .onError((error, stackTrace) => throw ApiException.wrap(error));
    if (resolve == false) {
      return Future.value(response.data);
    }
    return _resolve(r, response, factory);
  }

  static Future<T> put<T>(String path, dynamic data,
      [JsonFactory<T>? factory]) async {
    if (data is Map) {
      _removeNull(data);
    }
    String p = _path(path);

    final r = "put $p";
    Logger.debug(tag, ">>>> $r ${tojson(data)}");

    try {
      final response = await dio.put(p, data: data);
      return _resolve(r, response, factory);
    } catch (e, s) {
      Logger.err(tag, e);
      return Future.error(ApiException.wrap(e), s);
    }
  }

  static Future<T> post<T>(String path, dynamic data,
      [JsonFactory<T>? factory]) async {
    if (data is Map) {
      _removeNull(data);
    }
    String p = _path(path);

    final r = "post $p";
    Logger.debug(tag, ">>>> $r ${tojson(data)}");

    try {
      Response response;
      if (data is FormData) {
        response = await dio.post(
          p,
          data: data,
          options: Options(
            method: 'POST',
            contentType: Headers.multipartFormDataContentType,
          ),
        );
      } else {
        response = await dio.post(p, data: data);
      }
      return _resolve(r, response, factory);
    } catch (e, s) {
      Logger.err(tag, e);
      return Future.error(ApiException.wrap(e), s);
    }
  }

  static Future download(String url, String path) async {
    Logger.debug(tag, '>>> download $url');
    final resp = await dio.download(url, path);
    if (resp.statusCode != 200) {
      throw ApiException(resp.statusMessage ?? "-", resp.statusCode ?? -1);
    }
    Logger.debug(tag, '<<< download $url');
  }

  static String _path(String path) {
    if (path.startsWith("http")) {
      return path;
    }
    if (!path.startsWith("/")) {
      return "$_baseUrl$path";
    }
    return path;
  }

  static T _resolve<T>(String r, Response response, [JsonFactory<T>? factory]) {
    // throw ApiException('Not Found', 404);

    if (response.statusCode != 200) {
      Logger.err(
          tag, "<--- $r ${response.statusCode} ${response.statusMessage}");
      throw ApiException(
          response.statusMessage ?? "-", response.statusCode ?? -1);
    }
    if (response.headers.value('content-type')?.contains('application/json') !=
        true) {
      Logger.err(tag, "<--- $r Invalid response: ${response.data}");
      throw ApiException('Invalid response content', -1);
    }
    final json = response.data;
    Logger.debug(tag, "<--- $r ${tojson(json)}");

    final resp = CommonResponse.fromJson(json);
    if (resp.code != 100) {
      throw ApiException(resp.msg, resp.code);
    }

    if (resp.data != null && factory != null) {
      return factory(resp.data);
    }
    return resp.data as T;
  }

  static tojson(dynamic data) {
    if (data is FormData) {
      return "FormData: ${data.toString()}";
    }
    if (data is Map) {
      if (data.isEmpty) {
        return "{}";
      }
    } else {
      return "-";
    }
    return const JsonEncoder().convert(data);
  }

  static _removeNull(Map map) {
    map.removeWhere((key, value) => value == null);
    map.forEach((key, value) {
      if (value is Map) {
        _removeNull(value);
      }
      if (value is List) {
        for (var e in value) {
          if (e is Map) {
            _removeNull(e);
          }
        }
      }
    });
  }
}
