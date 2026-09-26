import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../models/entities.dart';
import '../widgets/common.dart';
import 'order_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final query = _query.toLowerCase();
    final customers = store.customers.where((customer) => customer.name.toLowerCase().contains(query) || customer.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''))).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('${s.t('customers')} · ${customers.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(tooltip: s.t('addCustomer'), onPressed: () => _addCustomer(store), icon: const Icon(Icons.person_add_alt_1_outlined)), const SizedBox(width: 8)],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(onChanged: (value) => setState(() => _query = value), decoration: InputDecoration(hintText: s.t('search'), prefixIcon: const Icon(Icons.search))),
        ),
        Expanded(
          child: customers.isEmpty
              ? EmptyState(icon: Icons.people_outline, title: s.t('emptyCustomers'), action: FilledButton.icon(onPressed: () => _addCustomer(store), icon: const Icon(Icons.add), label: Text(s.t('addCustomer'))))
              : RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _CustomerCard(customer: customers[index], onTap: () => _showCustomer(store, customers[index])),
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _addCustomer(store), child: const Icon(Icons.person_add_alt_1)),
    );
  }

  Future<void> _addCustomer(AppStore store) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final key = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(store.strings.t('addCustomer')),
        content: Form(
          key: key,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: name, decoration: InputDecoration(labelText: '${store.strings.t('name')} *'), validator: (value) => value == null || value.trim().isEmpty ? store.strings.t('required') : null),
            const SizedBox(height: 12),
            TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: store.strings.t('phone'))),
            const SizedBox(height: 12),
            TextFormField(controller: note, maxLines: 3, decoration: InputDecoration(labelText: store.strings.t('note'))),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))),
          FilledButton(onPressed: () {
            if (key.currentState?.validate() ?? false) Navigator.pop(dialogContext, true);
          }, child: Text(store.strings.t('save'))),
        ],
      ),
    );
    if (accepted == true) {
      await store.database.createCustomer(name: name.text, phone: phone.text, note: note.text);
      await store.refresh();
      if (mounted) showMessage(context, store.strings.t('saved'));
    }
    name.dispose();
    phone.dispose();
    note.dispose();
  }

  Future<void> _showCustomer(AppStore store, Customer customer) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CircleAvatar(radius: 32, child: Text(_initials(customer.name), style: const TextStyle(fontWeight: FontWeight.w800))),
            const SizedBox(height: 12),
            Text(customer.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text(customer.phone.isEmpty ? '—' : customer.phone, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
              Expanded(child: _CustomerMetric(label: store.strings.t('orders'), value: '${customer.orderCount}')),
              Expanded(child: _CustomerMetric(label: store.strings.t('debt'), value: Money.format(customer.debtMinor, store.settings.currency, store.localeCode))),
            ]))),
            if (customer.note.isNotEmpty) ...[const SizedBox(height: 12), Text(customer.note)],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(sheetContext);
                final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => OrderFormScreen(preselectedCustomerId: customer.id)));
                if (created == true) await store.refresh();
              },
              icon: const Icon(Icons.add),
              label: Text(store.strings.isRu ? 'Новый заказ для клиента' : 'New order for customer'),
            ),
          ]),
        ),
      ),
    );
  }

  String _initials(String name) => name.trim().split(RegExp(r'\s+')).take(2).map((e) => e.isEmpty ? '' : e[0].toUpperCase()).join();
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.onTap});
  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: onTap,
        leading: CircleAvatar(radius: 24, child: Text(customer.name.trim().isEmpty ? '?' : customer.name.trim()[0].toUpperCase())),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${customer.phone.isEmpty ? '—' : customer.phone}\n${store.strings.t('orders')}: ${customer.orderCount}'),
        isThreeLine: true,
        trailing: customer.debtMinor > 0 ? Text(Money.format(customer.debtMinor, store.settings.currency, store.localeCode), style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800)) : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CustomerMetric extends StatelessWidget {
  const _CustomerMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), const SizedBox(height: 4), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
}
