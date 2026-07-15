import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Dio-based HTTP client for the Homely backend API.
///
/// Automatically attaches the current Firebase user's ID token as a
/// Bearer token on every request via a Dio interceptor.
class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _dio.interceptors.add(_AuthInterceptor());
    debugPrint('ApiClient initialized with baseUrl: $baseUrl');
  }

  /// Manually set the Authorization Bearer header.
  /// Useful for cases where you want to override the auto-attached token.
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// GET a single JSON object.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParams,
    );
    return response.data!;
  }

  /// GET a JSON array.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      path,
      queryParameters: queryParams,
    );
    return response.data!;
  }

  /// POST with an optional JSON body.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: body,
    );
    return response.data!;
  }

  /// PATCH with an optional JSON body.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: body,
    );
    return response.data!;
  }

  /// PUT with an optional JSON body. Returns the decoded body as-is (some
  /// endpoints reply with an object, others with an array), so callers must
  /// not assume a Map.
  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dio.put<dynamic>(path, data: body);
    return response.data;
  }

  /// DELETE a resource; returns the response body (may be empty).
  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _dio.delete<Map<String, dynamic>>(path);
    return response.data ?? <String, dynamic>{};
  }

  /// POST multipart/form-data: string [fields] plus [files] keyed by field name.
  /// Each entry in a file list becomes one part under that field name, so
  /// repeated field names (e.g. `kitchenPhotos`) upload as an array.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    Map<String, List<String>> files = const {},
  }) async {
    final form = FormData();
    fields.forEach((k, v) => form.fields.add(MapEntry(k, v)));
    for (final entry in files.entries) {
      for (final filePath in entry.value) {
        form.files.add(MapEntry(
          entry.key,
          await MultipartFile.fromFile(
            filePath,
            filename: filePath.split('/').last,
          ),
        ));
      }
    }
    final response = await _dio.post<Map<String, dynamic>>(path, data: form);
    return response.data!;
  }
}

/// Dio interceptor that auto-attaches the current Firebase user's ID token
/// as a Bearer token on every outgoing request.
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // If the header is already set (e.g. via setAuthToken), don't overwrite.
    if (options.headers['Authorization'] != null) {
      return handler.next(options);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    debugPrint('API → ${options.method} ${options.uri}');
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('API error: ${err.type} ${err.message} ${err.response?.statusCode} ${err.response?.data}');
    handler.next(err);
  }
}
