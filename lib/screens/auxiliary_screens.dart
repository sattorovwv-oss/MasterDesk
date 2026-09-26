import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../widgets/common.dart';

const _uuid = Uuid();

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  List<Map<String, Object?>> _expenses = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final rows = await AppScope.of(context).database.raw.query('expenses', orderBy: 'created_at_utc DESC');
    if (mounted) setState(() => _expenses = rows);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final total = store.orders.fold<int>(0, (sum, item) => sum + item.totalMinor);
    final received = store.orders.fold<int>(0, (sum, item) => sum + item.paidMinor);
    final debt = store.orders.fold<int>(0, (sum, item) => sum + (item.balanceMinor > 0 ? item.balanceMinor : 0));
    final expenses = _expenses.fold<int>(0, (sum, item) => sum + (item['amount_minor']! as int));
    return Scaffold(
      appBar: AppBar(title: Text(s.t('finance'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(children: [PageContainer(maxWidth: 900, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth >= 700 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            _FinanceCard(width: width, label: s.t('total'), value: Money.format(total, store.settings.currency, store.localeCode), icon: Icons.receipt_long_outlined),
            _FinanceCard(width: width, label: s.t('paid'), value: Money.format(received, store.settings.currency, store.localeCode), icon: Icons.payments_outlined),
            _FinanceCard(width: width, label: s.t('debt'), value: Money.format(debt, store.settings.currency, store.localeCode), icon: Icons.schedule_outlined),
            _FinanceCard(width: width, label: s.isRu ? 'Расходы' : 'Expenses', value: Money.format(expenses, store.settings.currency, store.localeCode), icon: Icons.trending_down),
          ]);
        }),
        const SizedBox(height: 24),
        SectionHeader(title: s.isRu ? 'Расходы' : 'Expenses', action: TextButton.icon(onPressed: () => _addExpense(store), icon: const Icon(Icons.add), label: Text(s.t('save')))),
        if (_expenses.isEmpty) Text(s.t('noData')) else ..._expenses.map((item) => Card(child: ListTile(leading: const Icon(Icons.shopping_bag_outlined), title: Text(item['category']! as String, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text((item['note'] ?? '') as String), trailing: Text(Money.format(item['amount_minor']! as int, store.settings.currency, store.localeCode), style: const TextStyle(fontWeight: FontWeight.w800))))),
      ]))]),
    );
  }

  Future<void> _addExpense(AppStore store) async {
    final category = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(store.strings.isRu ? 'Добавить расход' : 'Add expense'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: category, decoration: InputDecoration(labelText: store.strings.t('category'))),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${store.strings.t('amount')} · ${store.settings.currency}')),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: InputDecoration(labelText: store.strings.t('note'))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save')))],
    ));
    if (accepted == true) {
      try {
        final value = Money.parseMinor(amount.text);
        if (value <= 0 || category.text.trim().isEmpty) throw const FormatException();
        await store.database.raw.insert('expenses', {'id': _uuid.v4(), 'category': category.text.trim(), 'amount_minor': value, 'note': note.text.trim(), 'created_at_utc': DateTime.now().toUtc().toIso8601String()});
        await _load();
      } catch (_) {
        if (mounted) showMessage(context, store.strings.t('invalidAmount'), error: true);
      }
    }
    category.dispose(); amount.dispose(); note.dispose();
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final counts = <String, int>{};
    for (final order in store.orders) {
      counts[order.status] = (counts[order.status] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(1, (max, value) => value > max ? value : max);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('reports'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(children: [PageContainer(maxWidth: 800, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(title: s.isRu ? 'Заказы по статусам' : 'Orders by status'),
        if (counts.isEmpty) EmptyState(icon: Icons.bar_chart_outlined, title: s.t('noData')) else ...counts.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(s.status(entry.key), style: const TextStyle(fontWeight: FontWeight.w700))), Text('${entry.value}')]),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: entry.value / maxCount, minHeight: 10, borderRadius: BorderRadius.circular(10)),
          ]),
        )),
      ]))]),
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, Object?>> _rows = const [];
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }
  Future<void> _load() async { final rows = await AppScope.of(context).database.raw.query('tasks', orderBy: 'completed ASC, due_at_utc ASC'); if (mounted) setState(() => _rows = rows); }
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context); final s = store.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('tasks'), style: const TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(onPressed: () => _add(store), icon: const Icon(Icons.add_task))]),
      body: _rows.isEmpty ? EmptyState(icon: Icons.task_alt_outlined, title: s.t('noData'), action: FilledButton.icon(onPressed: () => _add(store), icon: const Icon(Icons.add), label: Text(s.t('tasks')))) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _rows.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
        final row = _rows[index]; final done = row['completed'] == 1;
        return Card(child: CheckboxListTile(value: done, onChanged: (value) async { await store.database.raw.update('tasks', {'completed': value == true ? 1 : 0}, where: 'id = ?', whereArgs: [row['id']]); await _load(); }, title: Text(row['title']! as String, style: TextStyle(fontWeight: FontWeight.w700, decoration: done ? TextDecoration.lineThrough : null)), subtitle: row['due_at_utc'] == null ? null : Text(shortDate(DateTime.parse(row['due_at_utc']! as String))), secondary: const Icon(Icons.task_alt_outlined)));
      }),
      floatingActionButton: FloatingActionButton(onPressed: () => _add(store), child: const Icon(Icons.add)),
    );
  }
  Future<void> _add(AppStore store) async {
    final title = TextEditingController(); DateTime? due;
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: Text(store.strings.t('tasks')), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: InputDecoration(labelText: store.strings.isRu ? 'Название задачи' : 'Task title')), const SizedBox(height: 12), ListTile(title: Text(store.strings.t('deadline')), subtitle: Text(shortDate(due)), trailing: const Icon(Icons.event), onTap: () async { final value = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: due ?? DateTime.now()); if (value != null) setDialogState(() => due = value); })]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save')))])));
    if (accepted == true && title.text.trim().isNotEmpty) { await store.database.raw.insert('tasks', {'id': _uuid.v4(), 'title': title.text.trim(), 'due_at_utc': due?.toUtc().toIso8601String(), 'created_at_utc': DateTime.now().toUtc().toIso8601String()}); await _load(); }
    title.dispose();
  }
}

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, Object?>> _rows = const [];
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }
  Future<void> _load() async { final rows = await AppScope.of(context).database.raw.query('employees', where: 'archived = 0', orderBy: 'name'); if (mounted) setState(() => _rows = rows); }
  @override
  Widget build(BuildContext context) { final store = AppScope.of(context); return Scaffold(appBar: AppBar(title: Text(store.strings.t('employees'), style: const TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(onPressed: () => _add(store), icon: const Icon(Icons.person_add_alt))]), body: _rows.isEmpty ? EmptyState(icon: Icons.badge_outlined, title: store.strings.t('noData')) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _rows.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) { final row = _rows[index]; return Card(child: ListTile(leading: CircleAvatar(child: Text((row['name']! as String)[0].toUpperCase())), title: Text(row['name']! as String, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text((row['contact'] ?? '') as String), trailing: IconButton(tooltip: store.strings.isRu ? 'Архивировать' : 'Archive', onPressed: () async { await store.database.raw.update('employees', {'archived': 1}, where: 'id = ?', whereArgs: [row['id']]); await _load(); }, icon: const Icon(Icons.archive_outlined)))); }), floatingActionButton: FloatingActionButton(onPressed: () => _add(store), child: const Icon(Icons.add))); }
  Future<void> _add(AppStore store) async { final name = TextEditingController(); final contact = TextEditingController(); final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(store.strings.t('employees')), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: InputDecoration(labelText: store.strings.t('name'))), const SizedBox(height: 12), TextField(controller: contact, decoration: InputDecoration(labelText: store.strings.t('phone')))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save')))])); if (accepted == true && name.text.trim().isNotEmpty) { await store.database.raw.insert('employees', {'id': _uuid.v4(), 'name': name.text.trim(), 'contact': contact.text.trim(), 'created_at_utc': DateTime.now().toUtc().toIso8601String()}); await _load(); } name.dispose(); contact.dispose(); }
}

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, Object?>> _rows = const [];
  @override
  void didChangeDependencies() { super.didChangeDependencies(); _load(); }
  Future<void> _load() async { final rows = await AppScope.of(context).database.raw.query('services', where: 'active = 1', orderBy: 'name'); if (mounted) setState(() => _rows = rows); }
  @override
  Widget build(BuildContext context) { final store = AppScope.of(context); return Scaffold(appBar: AppBar(title: Text(store.strings.t('services'), style: const TextStyle(fontWeight: FontWeight.w700)), actions: [IconButton(onPressed: () => _add(store), icon: const Icon(Icons.add))]), body: _rows.isEmpty ? EmptyState(icon: Icons.home_repair_service_outlined, title: store.strings.t('noData')) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _rows.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) { final row = _rows[index]; return Card(child: ListTile(leading: const Icon(Icons.handyman_outlined), title: Text(row['name']! as String, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text((row['category'] ?? '') as String), trailing: Text(Money.format(row['price_minor']! as int, store.settings.currency, store.localeCode), style: const TextStyle(fontWeight: FontWeight.w800)))); }), floatingActionButton: FloatingActionButton(onPressed: () => _add(store), child: const Icon(Icons.add))); }
  Future<void> _add(AppStore store) async { final name = TextEditingController(); final category = TextEditingController(); final price = TextEditingController(); final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: Text(store.strings.t('services')), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: name, decoration: InputDecoration(labelText: store.strings.t('name'))), const SizedBox(height: 12), TextField(controller: category, decoration: InputDecoration(labelText: store.strings.t('category'))), const SizedBox(height: 12), TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${store.strings.t('salePrice')} · ${store.settings.currency}'))])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('save')))])); if (accepted == true && name.text.trim().isNotEmpty) { try { await store.database.raw.insert('services', {'id': _uuid.v4(), 'name': name.text.trim(), 'category': category.text.trim(), 'price_minor': Money.parseMinor(price.text), 'created_at_utc': DateTime.now().toUtc().toIso8601String()}); await _load(); } catch (_) { if (mounted) showMessage(context, store.strings.t('invalidAmount'), error: true); } } name.dispose(); category.dispose(); price.dispose(); }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.width, required this.label, required this.value, required this.icon});
  final double width; final String label; final String value; final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: 120, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const Spacer(), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]))));
}
