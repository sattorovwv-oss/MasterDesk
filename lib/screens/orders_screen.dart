import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../models/entities.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';
import 'order_form_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialFilter = 'all', this.standalone = false});

  final String initialFilter;
  final bool standalone;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late String _filter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final orders = store.orders.where((order) => _matches(order)).toList();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Text('${s.t('orders')} · ${orders.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: s.t('newOrder'),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _create(context, store),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: s.t('search'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () => setState(() => _query = ''), icon: const Icon(Icons.clear)),
            ),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('all', s.t('all')),
              _filterChip('active', s.t('activeOrders')),
              _filterChip('overdue', s.t('overdue')),
              _filterChip('ready', s.t('ready')),
              _filterChip('debt', s.t('debt')),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: _query.isEmpty ? s.t('emptyOrders') : (s.isRu ? 'Ничего не найдено' : 'No results found'),
                  action: _query.isEmpty ? FilledButton(onPressed: () => _create(context, store), child: Text(s.t('newOrder'))) : null,
                )
              : RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => OrderListCard(order: orders[index]),
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, store),
        icon: const Icon(Icons.add),
        label: Text(s.t('newOrder')),
      ),
    );
  }

  Widget _filterChip(String value, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  bool _matches(RepairOrder order) {
    final query = _query.toLowerCase().replaceAll(' ', '');
    final matchesQuery = query.isEmpty ||
        order.displayNumber.toLowerCase().contains(query) ||
        order.deviceName.toLowerCase().replaceAll(' ', '').contains(query) ||
        order.customerName.toLowerCase().replaceAll(' ', '').contains(query) ||
        order.customerPhone.replaceAll(RegExp(r'\D'), '').contains(query.replaceAll(RegExp(r'\D'), ''));
    if (!matchesQuery) return false;
    if (_filter == 'active') return !['ready', 'delivered', 'cancelled'].contains(order.status);
    if (_filter == 'ready') return order.status == 'ready';
    if (_filter == 'debt') return order.balanceMinor > 0;
    if (_filter == 'overdue') {
      return order.deadlineUtc != null && order.deadlineUtc!.isBefore(DateTime.now().toUtc()) && !['ready', 'delivered', 'cancelled'].contains(order.status);
    }
    return true;
  }

  Future<void> _create(BuildContext context, AppStore store) async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const OrderFormScreen()));
    if (created == true) await store.refresh();
  }
}

class OrderListCard extends StatelessWidget {
  const OrderListCard({required this.order, super.key});
  final RepairOrder order;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final overdue = order.deadlineUtc != null && order.deadlineUtc!.isBefore(DateTime.now().toUtc()) && !['ready', 'delivered', 'cancelled'].contains(order.status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)));
          await store.refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.displayNumber, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusChip(status: order.status, strings: store.strings),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              CircleAvatar(radius: 28, child: Icon(_icon(order.deviceCategory))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.deviceName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(order.customerName, style: Theme.of(context).textTheme.bodySmall),
              ])),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.schedule, size: 18, color: overdue ? Theme.of(context).colorScheme.error : null),
              const SizedBox(width: 6),
              Text(shortDate(order.deadlineUtc), style: TextStyle(color: overdue ? Theme.of(context).colorScheme.error : null, fontWeight: overdue ? FontWeight.w700 : null)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(store.strings.t('balance'), style: Theme.of(context).textTheme.bodySmall),
                Text(Money.format(order.balanceMinor, store.settings.currency, store.localeCode), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  IconData _icon(String category) => switch (category) {
        'phone' => Icons.smartphone,
        'tablet' => Icons.tablet_android,
        'laptop' => Icons.laptop,
        'pc' => Icons.desktop_windows,
        'appliance' => Icons.kitchen,
        _ => Icons.devices_other,
      };
}
