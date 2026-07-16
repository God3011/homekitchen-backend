import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../services/push_service.dart';
import 'discovery_screen.dart';
import 'orders_screen.dart';
import 'favorites_screen.dart';
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
    // Register this device for order-status push alerts (user is signed in).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      registerDeviceToken(ref.read(apiClientProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      DiscoveryScreen(),
      OrdersScreen(),
      FavoritesScreen(),
      ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border), label: 'Favorites'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
