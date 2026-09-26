import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../models/entities.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';
import 'orders_screen.dart';
import 'auxiliary_screens.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final recent = store.orders.take(3).toList();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(store.settings.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_today(s.isRu), style: Theme.of(context).textTheme.bodySmall),
        ]),
        actions: [
          IconButton(tooltip: s.t('tasks'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasksScreen())), icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageContainer(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(s.t('overview'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  s.isRu
                      ? 'Сегодня в работе ${store.dashboard['active'] ?? 0} заказов'
                      : '${store.dashboard['active'] ?? 0} active orders today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth >= 800
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    _MetricCard(width: itemWidth, icon: Icons.build_circle_outlined, label: s.t('activeOrders'), value: '${store.dashboard['active'] ?? 0}', onTap: () => _openOrders(context, 'active')),
                    _MetricCard(width: itemWidth, icon: Icons.check_circle_outline, label: s.t('readyPickup'), value: '${store.dashboard['ready'] ?? 0}', onTap: () => _openOrders(context, 'ready')),
                    _MetricCard(width: itemWidth, icon: Icons.schedule_outlined, label: s.t('overdue'), value: '${store.dashboard['overdue'] ?? 0}', onTap: () => _openOrders(context, 'overdue'), danger: (store.dashboard['overdue'] ?? 0) > 0),
                    _MetricCard(width: itemWidth, icon: Icons.payments_outlined, label: s.t('receivedToday'), value: Money.format(store.dashboard['todayMinor'] ?? 0, store.settings.currency, store.localeCode), onTap: () {}),
                  ]);
                }),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const OrderFormScreen()));
                    if (created == true) await store.refresh();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s.t('newOrder')),
                ),
                const SizedBox(height: 28),
                SectionHeader(title: s.t('recent'), action: TextButton(onPressed: () => _openOrders(context, 'all'), child: Text(s.t('showAll')))),
                if (recent.isEmpty)
                  EmptyState(
                    icon: Icons.handyman_outlined,
                    title: s.t('emptyOrders'),
                    action: FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderFormScreen())), child: Text(s.t('newOrder'))),
                  )
                else
                  ...recent.map((order) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecentOrder(order: order),
                      )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _openOrders(BuildContext context, String filter) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrdersScreen(initialFilter: filter, standalone: true)));

  static String _today(bool ru) {
    final date = DateTime.now();
    const ruMonths = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
    const enMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return ru ? '${date.day} ${ruMonths[date.month - 1]} ${date.year}' : '${enMonths[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.width, required this.icon, required this.label, required this.value, required this.onTap, this.danger = false});
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 118,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: danger ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                const Spacer(),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: danger ? Theme.of(context).colorScheme.error : null)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
      );
}

class _RecentOrder extends StatelessWidget {
  const _RecentOrder({required this.order});
  final RepairOrder order;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(radius: 26, child: Icon(_deviceIcon(order.deviceCategory))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.deviceName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${order.displayNumber} · ${order.customerName}', style: Theme.of(context).textTheme.bodySmall),
            ])),
            const SizedBox(width: 8),
            StatusChip(status: order.status, strings: store.strings),
          ]),
        ),
      ),
    );
  }
}

IconData _deviceIcon(String category) => switch (category) {
      'phone' => Icons.smartphone,
      'tablet' => Icons.tablet_android,
      'laptop' => Icons.laptop,
      'pc' => Icons.desktop_windows,
      'appliance' => Icons.kitchen,
      _ => Icons.devices_other,
    };
