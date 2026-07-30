import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';

/// First-run profile setup: name + home location → POST /customers/signup.
/// Shown by the auth gate when the user is signed in but has no Customer row.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  AddressResult? _addr;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (_addr == null) {
      setState(() => _error = 'Please set your home location');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post('/customers/signup', body: {
        'name': name,
        'lat': _addr!.lat,
        'lng': _addr!.lng,
      });

      trackEvent('sign_up_completed', {
        'user_id': result['id'] as String,
        'signup_method': 'phone_otp',
      });
      if (result['homeZoneId'] != null) {
        trackEvent('zone_detected', {
          'zone_id': result['homeZoneId'].toString(),
          'lat': _addr!.lat,
          'lng': _addr!.lng,
        });
      }

      // Refresh the profile so the auth gate navigates to home.
      ref.invalidate(customerProfileProvider);
    } catch (e) {
      setState(() {
        _error = 'Sign-up failed: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Homely'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            "Let's set up your profile.",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Your Name *'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          Text('Home location', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'We use this to show kitchens cooking near you.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          AddressPicker(
            api: ref.read(apiClientProvider),
            userAgentPackageName: 'com.homely.customer_app',
            onChanged: (r) => setState(() => _addr = r),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Get Started'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
