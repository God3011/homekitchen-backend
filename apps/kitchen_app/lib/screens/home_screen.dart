import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../providers/auth_provider.dart';
import '../providers/earnings_provider.dart';
import '../providers/kitchen_provider.dart';
import '../services/push_service.dart';
import 'earnings_screen.dart';
import 'orders_screen.dart';
import 'menu_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Register this device for order/stock push alerts (user is signed in here).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      registerDeviceToken(ref.read(apiClientProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      _DashboardPage(),
      MenuScreen(),
      OrdersScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      // IndexedStack keeps every tab mounted, so switching tabs doesn't dispose
      // and refetch each page's providers (e.g. dailyStatusProvider) — the
      // "Cooking Today?" toggle would otherwise flash OFF while it re-loaded.
      // It also preserves in-tab state like the Menu screen's staged edits.
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
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
    // Today's earnings come from the dedicated earnings API (netEarningsPaise:
    // gross − daily fees). The local orders list is kept for the order-count widget.
    final todayEarningsAsync = ref.watch(earningsProvider('today'));

    final kitchenName = profile.valueOrNull?.kitchenName ?? 'My Kitchen';
    final isCooking = dailyStatus.valueOrNull?['isCooking'] == true;
    final orders = ordersAsync.valueOrNull ?? const <Order>[];
    final now = DateTime.now();
    // Compare in LOCAL time — API timestamps are UTC, so convert before
    // comparing the calendar day (otherwise an order at 01:xx IST reads as
    // "yesterday" in UTC and gets excluded).
    bool isToday(DateTime d) {
      final l = d.toLocal();
      return l.year == now.year && l.month == now.month && l.day == now.day;
    }

    // "Today's Orders" = orders placed today (any status).
    final orderCount = orders.where((o) => isToday(o.placedAt)).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(kitchenName),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailyStatusProvider);
          ref.invalidate(ordersProvider(null));
          ref.invalidate(kitchenProfileProvider);
          ref.invalidate(earningsProvider('today'));
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
            const SizedBox(height: 16),
            // Today's earnings widget — backed by earningsProvider('today').
            // Tap navigates to the full Earnings & Payouts screen.
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EarningsScreen(),
                ),
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          size: 32, color: Colors.green),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Earnings",
                                style: Theme.of(context).textTheme.titleMedium),
                            todayEarningsAsync.when(
                              loading: () => const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (_, _) => Text(
                                '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              data: (s) => Text(
                                '₹${(s.netEarningsPaise / 100).toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
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
