import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/kitchen_provider.dart';
import 'orders_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _DashboardPage(),
      const OrdersScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }
}

class _DashboardPage extends ConsumerWidget {
  const _DashboardPage();

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(kitchenProfileProvider);
    final dailyStatus = ref.watch(dailyStatusProvider);
    final ordersAsync = ref.watch(ordersProvider(null));

    final kitchenName = profile.valueOrNull?.kitchenName ?? 'My Kitchen';
    final isCooking = dailyStatus.valueOrNull?['isCooking'] == true;
    final orderCount = ordersAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(kitchenName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyStatusProvider);
          ref.invalidate(ordersProvider(null));
          ref.invalidate(kitchenProfileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Cooking Today toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 32,
                        color: isCooking ? Colors.green : Colors.grey),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cooking Today?',
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            isCooking
                                ? 'You are accepting orders'
                                : 'Toggle on to start',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isCooking,
                      onChanged: (val) => _toggleCooking(ref, val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Order count
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 32, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's Orders",
                              style: Theme.of(context).textTheme.titleMedium),
                          Text('$orderCount order${orderCount != 1 ? 's' : ''}',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCooking(WidgetRef ref, bool value) async {
    final api = ref.read(apiClientProvider);
    final kitchenId = ref.read(kitchenProfileProvider).valueOrNull?.id;

    await api.post('/kitchens/me/daily-status', body: {
      'serviceDate': _todayStr(),
      'isCooking': value,
    });

    trackEvent('today_toggle_set', {
      'kitchen_id': kitchenId ?? '',
      'status': value.toString(),
      'date': _todayStr(),
    });

    ref.invalidate(dailyStatusProvider);
  }
}
