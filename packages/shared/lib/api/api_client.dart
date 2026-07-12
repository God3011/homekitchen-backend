import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  /// PUT with an optional JSON body.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      path,
      data: body,
    );
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

    return handler.next(options);
  }
}
