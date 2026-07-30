import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';


/// Single shared ApiClient — auto-attaches the Firebase bearer token.
final apiClientProvider = Provider<ApiClient>((_) {
  return ApiClient(baseUrl: apiBaseUrl, appRole: 'customer');
});
