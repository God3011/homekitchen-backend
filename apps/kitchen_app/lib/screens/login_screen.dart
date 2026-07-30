import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  String? _error;

  // Session-level guard: fire `seller_signup_started` once per genuine signup
  // start, even if the login screen is rebuilt or re-inserted in this session.
  static bool _signupStartTracked = false;

  @override
  void initState() {
    super.initState();
    if (!_signupStartTracked) {
      _signupStartTracked = true;
      trackEvent('seller_signup_started', {
        // Actual device/app locale, not a hardcoded value.
        'language_selected':
            WidgetsBinding.instance.platformDispatcher.locale.languageCode,
        // No attribution SDK yet — we don't know the real source.
        'referral_source': 'unknown',
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    final fullPhone = phone.startsWith('+') ? phone : '+91$phone';

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = ref.read(authServiceProvider);
    await auth.verifyPhone(
      phoneNumber: fullPhone,
      onCodeSent: (vid, _) {
        setState(() {
          _verificationId = vid;
          _loading = false;
        });
      },
      onError: (e) {
        setState(() {
          _error = e.message ?? 'Verification failed';
          _loading = false;
        });
      },
      onAutoVerify: (credential) async {
        await auth.signInWithOtp(
          verificationId: _verificationId ?? '',
          smsCode: credential.smsCode ?? '',
        );
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    final code = _otpController.text.trim();
    if (code.length != 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      // Auth state stream will trigger navigation automatically.
    } catch (e) {
      setState(() {
        _error = 'Invalid OTP. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOtpStage = _verificationId != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: HomelyLogoMark(size: 76)),
              const SizedBox(height: 16),
              const Center(child: HomelyWordmark(fontSize: 32)),
              const SizedBox(height: 4),
              Text('for Kitchens',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: HomelyColors.goldDeep,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text('Sign in to manage your kitchen',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 40),
              if (!isOtpStage) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixText: '+91 ',
                    hintText: 'Phone number',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send OTP'),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '6-digit OTP',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify & Sign In'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _verificationId = null;
                    _otpController.clear();
                  }),
                  child: const Text('Change phone number'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
