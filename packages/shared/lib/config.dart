/// API base URL. Override at build time with:
///   flutter run --dart-define=API_BASE_URL=http://your-host:3000/api
///
/// Defaults to 10.0.2.2 (Android emulator → host loopback).
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000/api',
);
