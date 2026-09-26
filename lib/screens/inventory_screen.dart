import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../models/entities.dart';
import '../widgets/common.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final parts = store.parts.where((part) {
      final matches = part.name.toLowerCase().contains(_query.toLowerCase()) || part.sku.toLowerCase().contains(_query.toLowerCase());
      if (!matches) return false;
      if (_filter == 'low') return part.quantity <= part.minimumQuantity;
      if (_filter == 'empty') return part.quantity == 0;
      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(title: Text('${s.t('inventory')} · ${parts.length}', style: const TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(tooltip: s.t('addPart'), onPressed: () => _addPart(store), icon: const Icon(Icons.add_box_outlined)), const SizedBox(width: 8)]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: TextField(onChanged: (value) => setState(() => _query = value), decoration: InputDecoration(hintText: s.t('search'), prefixIcon: const Icon(Icons.search)))),
        SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          _chip('all', s.t('all')),
          _chip('low', s.isRu ? 'Мало' : 'Low stock'),
          _chip('empty', s.isRu ? 'Нет в наличии' : 'Out of stock'),
        ])),
        Expanded(
          child: parts.isEmpty
              ? EmptyState(icon: Icons.inventory_2_outlined, title: s.t('emptyInventory'), action: FilledButton.icon(onPressed: () => _addPart(store), icon: const Icon(Icons.add), label: Text(s.t('addPart'))))
              : RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: parts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _PartCard(part: parts[index], onTap: () => _showPart(store, parts[index])),
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _addPart(store), child: const Icon(Icons.add)),
    );
  }

  Widget _chip(String value, String label) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(label), selected: _filter == value, onSelected: (_) => setState(() => _filter = value)));

  Future<void> _addPart(AppStore store) async {
    final name = TextEditingController();
    final sku = TextEditingController();
    final compatibility = TextEditingController();
    final quantity = TextEditingController(text: '0');
    final minimum = TextEditingController(text: '0');
    final purchase = TextEditingController();
    final sale = TextEditingController();
    final location = TextEditingController();
    final key = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(store.strings.t('addPart')),
        content: Form(
          key: key,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: name, decoration: InputDecoration(labelText: '${store.strings.t('name')} *'), validator: (value) => value == null || value.trim().isEmpty ? store.strings.t('required') : null),
            const SizedBox(height: 10),
            TextFormField(controller: sku, decoration: const InputDecoration(labelText: 'SKU')),
            const SizedBox(height: 10),
            TextFormField(controller: compatibility, decoration: InputDecoration(labelText: store.strings.isRu ? 'Совместимость' : 'Compatibility')),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextFormField(controller: quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: store.strings.t('stock')))), const SizedBox(width: 10), Expanded(child: TextFormField(controller: minimum, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: store.strings.t('minimum'))))]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextFormField(controller: purchase, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: store.strings.t('buyPrice')))), const SizedBox(width: 10), Expanded(child: TextFormField(controller: sale, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: store.strings.t('salePrice'))))]),
            const SizedBox(height: 10),
            TextFormField(controller: location, decoration: InputDecoration(labelText: store.strings.isRu ? 'Место хранения' : 'Location')),
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
      try {
        await store.database.createPart(name: name.text, sku: sku.text, compatibility: compatibility.text, quantity: int.parse(quantity.text), minimumQuantity: int.parse(minimum.text), purchasePriceMinor: Money.parseMinor(purchase.text), sellingPriceMinor: Money.parseMinor(sale.text), location: location.text);
        await store.refresh();
      } catch (_) {
        if (mounted) showMessage(context, store.strings.t('invalidAmount'), error: true);
      }
    }
    for (final controller in [name, sku, compatibility, quantity, minimum, purchase, sale, location]) {
      controller.dispose();
    }
  }

  Future<void> _showPart(AppStore store, Part part) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(part.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (part.sku.isNotEmpty) Text('SKU: ${part.sku}'),
            const SizedBox(height: 16),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _StockMetric(label: store.strings.t('stock'), value: '${part.quantity}'),
              _StockMetric(label: store.strings.t('minimum'), value: '${part.minimumQuantity}'),
              _StockMetric(label: store.strings.t('salePrice'), value: Money.format(part.sellingPriceMinor, store.settings.currency, store.localeCode)),
            ]))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () async { Navigator.pop(sheetContext); await _adjust(store, part, positive: true); }, icon: const Icon(Icons.add), label: Text(store.strings.t('addStock')))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: part.quantity <= 0 ? null : () async { Navigator.pop(sheetContext); await _adjust(store, part, positive: false); }, icon: const Icon(Icons.remove), label: Text(store.strings.t('writeOff')))),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _adjust(AppStore store, Part part, {required bool positive}) async {
    final controller = TextEditingController(text: '1');
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(positive ? store.strings.t('addStock') : store.strings.t('writeOff')),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: store.strings.isRu ? 'Количество' : 'Quantity')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save')))],
    ));
    if (accepted == true) {
      try {
        final value = int.parse(controller.text);
        if (value <= 0) throw const FormatException();
        await store.database.adjustStock(partId: part.id, delta: positive ? value : -value, type: positive ? 'receipt' : 'write_off');
        await store.refresh();
      } catch (_) {
        if (mounted) showMessage(context, store.strings.isRu ? 'Недостаточно запчастей или неверное количество' : 'Not enough stock or invalid quantity', error: true);
      }
    }
    controller.dispose();
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part, required this.onTap});
  final Part part;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final low = part.quantity <= part.minimumQuantity;
    return Card(child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      onTap: onTap,
      leading: CircleAvatar(child: Icon(part.quantity == 0 ? Icons.remove_shopping_cart_outlined : Icons.memory_outlined)),
      title: Text(part.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([if (part.sku.isNotEmpty) 'SKU ${part.sku}', if (part.compatibility.isNotEmpty) part.compatibility].join(' · ')),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${part.quantity} ${store.strings.isRu ? 'шт.' : 'pcs'}', style: TextStyle(fontWeight: FontWeight.w800, color: low ? Theme.of(context).colorScheme.error : null)),
        Text(Money.format(part.sellingPriceMinor, store.settings.currency, store.localeCode), style: Theme.of(context).textTheme.bodySmall),
      ]),
    ));
  }
}

class _StockMetric extends StatelessWidget {
  const _StockMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Flexible(child: Column(children: [Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)]));
}
