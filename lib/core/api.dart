import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'env.dart';
import 'storage.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_AuthInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {dynamic data}) =>
      _request(() => _dio.post(path, data: data));

  Future<dynamic> patch(String path, {dynamic data}) =>
      _request(() => _dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _request(() => _dio.delete(path));

  Future<dynamic> _request(Future<Response> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map<String, dynamic> && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    } on DioException catch (e) {
      final res = e.response;
      if (res != null) {
        final body = res.data;
        final msg = body is Map
            ? (body['message'] ?? 'Something went wrong').toString()
            : 'Something went wrong';
        throw ApiError(msg, res.statusCode);
      }
      throw ApiError(_netMsg(e.type));
    }
  }

  static String _netMsg(DioExceptionType t) => switch (t) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'Connection timed out. Check your internet.',
        DioExceptionType.connectionError =>
          'Cannot reach server. Make sure backend is running.',
        _ => 'An unexpected error occurred.',
      };
}

class ApiError implements Exception {
  final String message;
  final int? statusCode;

  const ApiError(this.message, [this.statusCode]);

  bool get isUnauthorized => statusCode == 401;
  bool get isConflict => statusCode == 409;

  @override
  String toString() => message;
}

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AppStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
