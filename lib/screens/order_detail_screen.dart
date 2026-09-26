import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../models/entities.dart';
import '../services/export_service.dart';
import '../widgets/common.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({required this.orderId, super.key});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  RepairOrder? _order;
  List<Map<String, Object?>> _items = const [];
  List<Map<String, Object?>> _payments = const [];
  List<OrderEvent> _events = const [];
  bool _loading = true;
  bool _busy = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final db = AppScope.of(context).database;
    final results = await Future.wait([
      db.getOrder(widget.orderId),
      db.getOrderItems(widget.orderId),
      db.getPayments(widget.orderId),
      db.getEvents(widget.orderId),
    ]);
    if (!mounted) return;
    setState(() {
      _order = results[0] as RepairOrder?;
      _items = results[1] as List<Map<String, Object?>>;
      _payments = results[2] as List<Map<String, Object?>>;
      _events = results[3] as List<OrderEvent>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final order = _order;
    if (order == null) {
      return Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.error_outline, title: s.t('noData')));
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(order.displayNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: s.t('exportPdf'),
              onPressed: _busy ? null : () => _sharePdf(store, order),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [Tab(text: s.t('overview')), Tab(text: s.t('works')), Tab(text: s.t('payment')), Tab(text: s.t('history'))],
          ),
        ),
        body: TabBarView(children: [
          _overview(store, order),
          _work(store, order),
          _payment(store, order),
          _history(store),
        ]),
      ),
    );
  }

  Widget _overview(AppStore store, RepairOrder order) {
    final s = store.strings;
    final canAdvance = !['delivered', 'cancelled'].contains(order.status);
    return ListView(children: [
      PageContainer(
        maxWidth: 800,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 34, child: Icon(_deviceIcon(order.deviceCategory), size: 32)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.deviceName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              StatusChip(status: order.status, strings: s),
            ])),
          ]),
          const SizedBox(height: 20),
          if (canAdvance)
            FilledButton.icon(
              onPressed: _busy ? null : () => _advance(store),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text('${s.t('nextStatus')}: ${s.status(_nextStatus(order.status))}'),
            ),
          const SizedBox(height: 20),
          _InfoCard(title: s.t('customer'), icon: Icons.person_outline, rows: [(s.t('name'), order.customerName), (s.t('phone'), order.customerPhone)]),
          const SizedBox(height: 12),
          _InfoCard(title: s.t('device'), icon: Icons.devices_outlined, rows: [
            (s.t('problem'), order.problem),
            (s.t('condition'), order.conditionNote),
            (s.t('serial'), order.serialNumber),
            (s.t('deadline'), shortDate(order.deadlineUtc)),
            (s.t('priority'), order.priority),
          ]),
          if (order.internalNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoCard(title: s.isRu ? 'Внутренняя заметка' : 'Internal note', icon: Icons.lock_outline, rows: [('', order.internalNote)]),
          ],
        ]),
      ),
    ]);
  }

  Widget _work(AppStore store, RepairOrder order) {
    final s = store.strings;
    return Column(children: [
      Expanded(
        child: _items.isEmpty
            ? EmptyState(icon: Icons.handyman_outlined, title: s.isRu ? 'Работы и запчасти не добавлены' : 'No work or parts added')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final qty = item['quantity']! as int;
                  final price = item['unit_price_minor']! as int;
                  return Card(
                    child: ListTile(
                      leading: Icon(item['type'] == 'part' ? Icons.memory_outlined : Icons.handyman_outlined),
                      title: Text(item['name']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('$qty × ${Money.format(price, store.settings.currency, store.localeCode)}'),
                      trailing: Text(Money.format(qty * price, store.settings.currency, store.localeCode), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  );
                },
              ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : () => _addItem(store), icon: const Icon(Icons.add), label: Text(s.isRu ? 'Добавить позицию' : 'Add item'))),
        ),
      ),
    ]);
  }

  Widget _payment(AppStore store, RepairOrder order) {
    final s = store.strings;
    return ListView(children: [
      PageContainer(
        maxWidth: 800,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _MoneyRow(label: s.t('total'), value: Money.format(order.totalMinor, store.settings.currency, store.localeCode)),
                _MoneyRow(label: s.t('paid'), value: Money.format(order.paidMinor, store.settings.currency, store.localeCode)),
                const Divider(height: 24),
                _MoneyRow(label: order.balanceMinor < 0 ? (s.isRu ? 'К возврату клиенту' : 'Refund due') : s.t('balance'), value: Money.format(order.balanceMinor.abs(), store.settings.currency, store.localeCode), strong: true),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _busy ? null : () => _recordPayment(store, refund: false), icon: const Icon(Icons.add_card), label: Text(s.t('addPayment')))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: order.paidMinor <= 0 || _busy ? null : () => _recordPayment(store, refund: true), icon: const Icon(Icons.undo), label: Text(s.isRu ? 'Возврат' : 'Refund'))),
          ]),
          const SizedBox(height: 20),
          SectionHeader(title: s.t('history')),
          if (_payments.isEmpty)
            Text(s.t('noData'))
          else
            ..._payments.map((payment) {
              final refund = payment['kind'] == 'refund';
              return Card(
                child: ListTile(
                  leading: Icon(refund ? Icons.undo : Icons.payments_outlined, color: refund ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                  title: Text(refund ? (s.isRu ? 'Возврат' : 'Refund') : s.t('payment'), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${payment['method']} · ${shortDate(DateTime.parse(payment['created_at_utc']! as String))}'),
                  trailing: Text('${refund ? '−' : '+'}${Money.format(payment['amount_minor']! as int, store.settings.currency, store.localeCode)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              );
            }),
        ]),
      ),
    ]);
  }

  Widget _history(AppStore store) => _events.isEmpty
      ? EmptyState(icon: Icons.history, title: store.strings.t('noData'))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            final event = _events[index];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.history, size: 18)),
              title: Text(store.localeCode == 'ru' ? event.descriptionRu : event.descriptionEn),
              subtitle: Text('${shortDate(event.createdAtUtc)} · ${_time(event.createdAtUtc)}'),
            );
          },
        );

  Future<void> _advance(AppStore store) async {
    setState(() => _busy = true);
    try {
      await store.database.advanceOrderStatus(widget.orderId);
      await store.refresh();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem(AppStore store) async {
    final name = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final price = TextEditingController();
    var type = 'service';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(store.strings.isRu ? 'Добавить позицию' : 'Add item'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            SegmentedButton<String>(
              segments: [ButtonSegment(value: 'service', label: Text(store.strings.isRu ? 'Услуга' : 'Service')), ButtonSegment(value: 'part', label: Text(store.strings.t('part')))],
              selected: {type},
              onSelectionChanged: (value) => setDialogState(() => type = value.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: name, decoration: InputDecoration(labelText: store.strings.isRu ? 'Наименование' : 'Name')),
            const SizedBox(height: 12),
            TextField(controller: quantity, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: store.strings.isRu ? 'Количество' : 'Quantity')),
            const SizedBox(height: 12),
            TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${store.strings.t('salePrice')} · ${store.settings.currency}')),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save'))),
          ],
        ),
      ),
    );
    if (result != true) return;
    try {
      final qty = int.parse(quantity.text);
      final minor = Money.parseMinor(price.text);
      if (name.text.trim().isEmpty) throw const FormatException();
      setState(() => _busy = true);
      await store.database.addOrderItem(orderId: widget.orderId, name: name.text, type: type, quantity: qty, unitPriceMinor: minor);
      await store.refresh();
      await _load();
    } catch (_) {
      if (mounted) showMessage(context, store.strings.t('invalidAmount'), error: true);
    } finally {
      name.dispose();
      quantity.dispose();
      price.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordPayment(AppStore store, {required bool refund}) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var method = 'cash';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(refund ? (store.strings.isRu ? 'Оформить возврат' : 'Record refund') : store.strings.t('addPayment')),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${store.strings.t('amount')} · ${store.settings.currency}')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: InputDecoration(labelText: store.strings.t('method')),
              items: [('cash', store.strings.t('cash')), ('transfer', store.strings.t('transfer')), ('card', store.strings.t('card')), ('other', store.strings.t('other'))].map((item) => DropdownMenuItem(value: item.$1, child: Text(item.$2))).toList(),
              onChanged: (value) => setDialogState(() => method = value ?? 'cash'),
            ),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 2, decoration: InputDecoration(labelText: store.strings.t('note'))),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save'))),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      final value = Money.parseMinor(amount.text);
      setState(() => _busy = true);
      await store.database.addPayment(orderId: widget.orderId, amountMinor: value, method: method, note: note.text, refund: refund);
      await store.refresh();
      await _load();
    } catch (_) {
      if (mounted) showMessage(context, store.strings.t('invalidAmount'), error: true);
    } finally {
      amount.dispose();
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdf(AppStore store, RepairOrder order) async {
    setState(() => _busy = true);
    try {
      await ExportService.shareOrderPdf(order: order, settings: store.settings, items: _items, isRu: store.localeCode == 'ru');
    } catch (_) {
      if (mounted) showMessage(context, store.strings.isRu ? 'Не удалось создать PDF' : 'Could not create PDF', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _nextStatus(String status) => const {
        'received': 'diagnosing',
        'diagnosing': 'awaiting_approval',
        'awaiting_approval': 'in_progress',
        'awaiting_parts': 'in_progress',
        'in_progress': 'ready',
        'ready': 'delivered',
      }[status] ?? status;

  IconData _deviceIcon(String category) => switch (category) {
        'phone' => Icons.smartphone,
        'tablet' => Icons.tablet_android,
        'laptop' => Icons.laptop,
        'pc' => Icons.desktop_windows,
        'appliance' => Icons.kitchen,
        _ => Icons.devices_other,
      };

  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 12),
            ...rows.where((row) => row.$2.isNotEmpty).map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (row.$1.isNotEmpty) Expanded(child: Text(row.$1, style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(flex: row.$1.isEmpty ? 1 : 2, child: Text(row.$2, textAlign: row.$1.isEmpty ? TextAlign.start : TextAlign.end)),
                  ]),
                )),
          ]),
        ),
      );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? const TextStyle(fontWeight: FontWeight.w800) : null)),
          Text(value, style: TextStyle(fontSize: strong ? 20 : 15, fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}
