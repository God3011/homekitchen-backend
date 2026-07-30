import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared/shared.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'services/push_service.dart';

class _AllowAllHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

Future<void> main() async {
  HttpOverrides.global = _AllowAllHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Debug: test connectivity
  debugPrint('Testing: $apiBaseUrl/health');
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    final request = await client.getUrl(Uri.parse('$apiBaseUrl/health'));
    final response = await request.close();
    debugPrint('  OK: ${response.statusCode}');
    client.close();
  } catch (e) {
    debugPrint('  FAIL: $e');
  }

  await Firebase.initializeApp();
  await initPushForApp();
  runApp(const ProviderScope(child: HomelyKitchenApp()));
}

class HomelyKitchenApp extends ConsumerWidget {
  const HomelyKitchenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Homely Kitchen',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

/// Routes based on auth + profile state:
///   - Not signed in -> LoginScreen
///   - Signed in but no kitchen profile -> SignupScreen
///   - Signed in with profile -> HomeScreen
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();
        final profile = ref.watch(kitchenProfileProvider);
        return profile.when(
          data: (kitchen) {
            if (kitchen == null) return const SignupScreen();
            return const HomeScreen();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => const SignupScreen(),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, s) => const LoginScreen(),
    );
  }
}
