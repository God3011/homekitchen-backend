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
      registerDeviceTokenForApp(ref.read(apiClientProvider));
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
            _CookingCard(
              isCooking: isCooking,
              onChanged: (v) => _toggleCooking(ref, v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.receipt_long_rounded,
                    label: "Today's orders",
                    accent: HomelyColors.blueDeep,
                    value: Text(
                      '$orderCount',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: HomelyColors.blueDeep),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.account_balance_wallet_rounded,
                    label: "Today's earnings",
                    accent: HomelyColors.goldDeep,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EarningsScreen()),
                    ),
                    value: todayEarningsAsync.when(
                      loading: () => const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, _) => Text('—',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      data: (s) => Text(
                        formatPaise(s.netEarningsPaise),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: HomelyColors.goldDeep),
                      ),
                    ),
                  ),
                ),
              ],
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

/// The "Cooking Today" toggle: a sage-filled card when live, quiet white when
/// off — the single most important control on the dashboard.
class _CookingCard extends StatelessWidget {
  const _CookingCard({required this.isCooking, required this.onChanged});
  final bool isCooking;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final fg = isCooking ? Colors.white : HomelyColors.ink;
    final fgSoft =
        isCooking ? Colors.white.withValues(alpha: 0.85) : HomelyColors.inkSoft;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isCooking ? HomelyColors.sage : HomelyColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isCooking ? HomelyColors.sage : HomelyColors.line),
      ),
      child: Row(
        children: [
          Icon(
            isCooking
                ? Icons.local_fire_department_rounded
                : Icons.restaurant_menu_rounded,
            size: 30,
            color: isCooking ? Colors.white : HomelyColors.inkFaint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cooking Today',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: fg)),
                Text(
                  isCooking
                      ? "You're visible to customers nearby"
                      : 'Toggle on to start taking orders',
                  style: TextStyle(fontSize: 12.5, color: fgSoft),
                ),
              ],
            ),
          ),
          Switch(
            value: isCooking,
            onChanged: onChanged,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? Colors.white.withValues(alpha: 0.35)
                  : HomelyColors.inkFaint.withValues(alpha: 0.4),
            ),
            trackOutlineColor:
                const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// A dashboard metric tile: an accent-tinted icon, a caption, and a big value.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomelyColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HomelyColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(height: 12),
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: HomelyColors.inkFaint)),
              const SizedBox(height: 3),
              value,
            ],
          ),
        ),
      ),
    );
  }
}
