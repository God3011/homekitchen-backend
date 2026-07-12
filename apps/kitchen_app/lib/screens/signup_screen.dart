import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _cookNameController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _cookNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Kitchen name is required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{'kitchenName': name};
      final cookName = _cookNameController.text.trim();
      if (cookName.isNotEmpty) body['cookName'] = cookName;

      final result = await api.post('/kitchens/signup', body: body);

      trackEvent('seller_signup_completed', {
        'kitchen_id': result['id'] as String,
        'zone_id': result['zoneId']?.toString() ?? '',
      });

      // Refresh the profile so the auth gate navigates to home.
      ref.invalidate(kitchenProfileProvider);
    } catch (e) {
      setState(() {
        _error = 'Signup failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Kitchen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome! Let\'s get your kitchen listed.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Kitchen Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cookNameController,
              decoration: const InputDecoration(labelText: 'Cook Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Kitchen'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
