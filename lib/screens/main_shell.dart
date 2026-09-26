import 'package:flutter/material.dart';

import '../data/app_store.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'more_screen.dart';
import 'orders_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _icons = [
    Icons.dashboard_outlined,
    Icons.receipt_long_outlined,
    Icons.people_outline,
    Icons.inventory_2_outlined,
    Icons.more_horiz,
  ];
  static const _selectedIcons = [
    Icons.dashboard_rounded,
    Icons.receipt_long_rounded,
    Icons.people_rounded,
    Icons.inventory_2_rounded,
    Icons.more_horiz,
  ];

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final labels = [s.t('home'), s.t('orders'), s.t('customers'), s.t('inventory'), s.t('more')];
    const pages = [DashboardScreen(), OrdersScreen(), CustomersScreen(), InventoryScreen(), MoreScreen()];
    final wide = MediaQuery.sizeOf(context).width >= 600;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          SafeArea(
            child: NavigationRail(
              selectedIndex: _index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (value) => setState(() => _index = value),
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.build_rounded, color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              destinations: List.generate(labels.length, (i) => NavigationRailDestination(icon: Icon(_icons[i]), selectedIcon: Icon(_selectedIcons[i]), label: Text(labels[i]))),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: IndexedStack(index: _index, children: pages)),
        ]),
      );
    }
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: List.generate(labels.length, (i) => NavigationDestination(icon: Icon(_icons[i]), selectedIcon: Icon(_selectedIcons[i]), label: labels[i])),
      ),
    );
  }
}
