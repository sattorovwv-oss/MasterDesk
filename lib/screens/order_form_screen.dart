import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/app_store.dart';
import '../models/entities.dart';
import '../widgets/common.dart';
import 'order_detail_screen.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, this.preselectedCustomerId});

  final String? preselectedCustomerId;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerNote = TextEditingController();
  final _deviceName = TextEditingController();
  final _problem = TextEditingController();
  final _condition = TextEditingController();
  final _serial = TextEditingController();
  final _estimate = TextEditingController();
  final _deposit = TextEditingController();
  final _internalNote = TextEditingController();
  int _step = 0;
  bool _newCustomer = true;
  bool _saving = false;
  String? _customerId;
  String _category = 'phone';
  String _priority = 'normal';
  String _method = 'cash';
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _customerId = widget.preselectedCustomerId;
    _newCustomer = widget.preselectedCustomerId == null;
  }

  @override
  void dispose() {
    for (final controller in [_customerName, _customerPhone, _customerNote, _deviceName, _problem, _condition, _serial, _estimate, _deposit, _internalNote]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('newOrder'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Stepper(
              currentStep: _step,
              onStepTapped: (value) {
                if (value < _step) setState(() => _step = value);
              },
              onStepContinue: _saving ? null : () => _continue(store),
              onStepCancel: _step == 0 ? null : () => setState(() => _step--),
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: details.onStepContinue,
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_step == 3 ? s.t('acceptDevice') : s.t('continue')),
                    ),
                  ),
                  if (_step > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(onPressed: details.onStepCancel, child: Text(s.t('back'))),
                  ],
                ]),
              ),
              steps: [
                Step(title: Text(s.t('customer')), isActive: _step >= 0, state: _state(0), content: _customerStep(store)),
                Step(title: Text(s.t('device')), isActive: _step >= 1, state: _state(1), content: _deviceStep(store)),
                Step(title: Text(s.t('workAndDeadline')), isActive: _step >= 2, state: _state(2), content: _workStep(store)),
                Step(title: Text(s.t('review')), isActive: _step >= 3, state: _state(3), content: _reviewStep(store)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  StepState _state(int index) => _step > index ? StepState.complete : (_step == index ? StepState.editing : StepState.indexed);

  Widget _customerStep(AppStore store) {
    final s = store.strings;
    final hasCustomers = store.customers.isNotEmpty;
    return Form(
      key: _formKeys[0],
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (hasCustomers && widget.preselectedCustomerId == null) ...[
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(s.isRu ? 'Существующий' : 'Existing'), icon: const Icon(Icons.person_search)),
              ButtonSegment(value: true, label: Text(s.isRu ? 'Новый' : 'New'), icon: const Icon(Icons.person_add_alt)),
            ],
            selected: {_newCustomer},
            onSelectionChanged: (value) => setState(() => _newCustomer = value.first),
          ),
          const SizedBox(height: 16),
        ],
        if (!_newCustomer)
          DropdownButtonFormField<String>(
            initialValue: _customerId,
            decoration: InputDecoration(labelText: '${s.t('customer')} *', prefixIcon: const Icon(Icons.person_outline)),
            items: store.customers.map((customer) => DropdownMenuItem(value: customer.id, child: Text('${customer.name}${customer.phone.isEmpty ? '' : ' · ${customer.phone}'}'))).toList(),
            onChanged: (value) => setState(() => _customerId = value),
            validator: (value) => value == null ? s.t('required') : null,
          )
        else ...[
          TextFormField(controller: _customerName, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: '${s.t('name')} *', prefixIcon: const Icon(Icons.person_outline)), validator: _required(store)),
          const SizedBox(height: 12),
          TextFormField(controller: _customerPhone, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: '${s.t('phone')} *', prefixIcon: const Icon(Icons.phone_outlined)), validator: _required(store)),
          const SizedBox(height: 12),
          TextFormField(controller: _customerNote, maxLines: 3, decoration: InputDecoration(labelText: s.t('note'), prefixIcon: const Icon(Icons.notes_outlined))),
        ],
      ]),
    );
  }

  Widget _deviceStep(AppStore store) {
    final s = store.strings;
    final categories = <String, String>{
      'phone': s.isRu ? 'Телефон' : 'Phone',
      'tablet': s.isRu ? 'Планшет' : 'Tablet',
      'laptop': s.isRu ? 'Ноутбук' : 'Laptop',
      'pc': s.isRu ? 'Компьютер' : 'PC',
      'appliance': s.isRu ? 'Бытовая техника' : 'Appliance',
      'other': s.t('other'),
    };
    return Form(
      key: _formKeys[1],
      child: Column(children: [
        DropdownButtonFormField<String>(initialValue: _category, decoration: InputDecoration(labelText: '${s.t('category')} *', prefixIcon: const Icon(Icons.category_outlined)), items: categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(), onChanged: (value) => setState(() => _category = value ?? 'other')),
        const SizedBox(height: 12),
        TextFormField(controller: _deviceName, textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: '${s.t('model')} *', prefixIcon: const Icon(Icons.devices_outlined)), validator: _required(store)),
        const SizedBox(height: 12),
        TextFormField(controller: _problem, maxLines: 3, decoration: InputDecoration(labelText: '${s.t('problem')} *', prefixIcon: const Icon(Icons.report_problem_outlined)), validator: _required(store)),
        const SizedBox(height: 12),
        TextFormField(controller: _condition, maxLines: 2, decoration: InputDecoration(labelText: s.t('condition'), prefixIcon: const Icon(Icons.fact_check_outlined))),
        const SizedBox(height: 12),
        TextFormField(controller: _serial, decoration: InputDecoration(labelText: s.t('serial'), prefixIcon: const Icon(Icons.numbers_outlined))),
      ]),
    );
  }

  Widget _workStep(AppStore store) {
    final s = store.strings;
    return Form(
      key: _formKeys[2],
      child: Column(children: [
        DropdownButtonFormField<String>(
          initialValue: _priority,
          decoration: InputDecoration(labelText: s.t('priority'), prefixIcon: const Icon(Icons.flag_outlined)),
          items: [('normal', s.t('normal')), ('high', s.t('high')), ('urgent', s.t('urgent'))].map((item) => DropdownMenuItem(value: item.$1, child: Text(item.$2))).toList(),
          onChanged: (value) => setState(() => _priority = value ?? 'normal'),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(s.t('deadline')),
            subtitle: Text(shortDate(_deadline)),
            trailing: _deadline == null ? const Icon(Icons.chevron_right) : IconButton(onPressed: () => setState(() => _deadline = null), icon: const Icon(Icons.clear)),
            onTap: _pickDeadline,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _estimate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${s.t('estimate')} · ${store.settings.currency}', prefixIcon: const Icon(Icons.calculate_outlined)), validator: _moneyValidator(store, allowEmpty: true)),
        const SizedBox(height: 12),
        TextFormField(controller: _deposit, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${s.t('deposit')} · ${store.settings.currency}', prefixIcon: const Icon(Icons.payments_outlined)), validator: _moneyValidator(store, allowEmpty: true)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _method,
          decoration: InputDecoration(labelText: s.t('method'), prefixIcon: const Icon(Icons.account_balance_wallet_outlined)),
          items: [('cash', s.t('cash')), ('transfer', s.t('transfer')), ('card', s.t('card')), ('other', s.t('other'))].map((item) => DropdownMenuItem(value: item.$1, child: Text(item.$2))).toList(),
          onChanged: (value) => setState(() => _method = value ?? 'cash'),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _internalNote, maxLines: 3, decoration: InputDecoration(labelText: s.isRu ? 'Внутренняя заметка' : 'Internal note', prefixIcon: const Icon(Icons.lock_outline))),
      ]),
    );
  }

  Widget _reviewStep(AppStore store) {
    final s = store.strings;
    final selectedCustomers = store.customers.where((c) => c.id == _customerId).toList();
    final customer = _newCustomer
        ? _customerName.text
        : (selectedCustomers.isEmpty ? '—' : selectedCustomers.first.name);
    int estimate = 0;
    int deposit = 0;
    try {
      estimate = Money.parseMinor(_estimate.text);
      deposit = Money.parseMinor(_deposit.text);
    } on FormatException {
      // The previous form step owns the validation message.
    }
    return Form(
      key: _formKeys[3],
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _ReviewRow(label: s.t('customer'), value: customer),
            _ReviewRow(label: s.t('device'), value: _deviceName.text),
            _ReviewRow(label: s.t('problem'), value: _problem.text),
            _ReviewRow(label: s.t('deadline'), value: shortDate(_deadline)),
            _ReviewRow(label: s.t('estimate'), value: Money.format(estimate, store.settings.currency, store.localeCode)),
            _ReviewRow(label: s.t('deposit'), value: Money.format(deposit, store.settings.currency, store.localeCode)),
          ]),
        ),
      ),
    );
  }

  String? Function(String?) _required(AppStore store) => (value) => value == null || value.trim().isEmpty ? store.strings.t('required') : null;

  String? Function(String?) _moneyValidator(AppStore store, {bool allowEmpty = false}) => (value) {
        if (allowEmpty && (value == null || value.trim().isEmpty)) return null;
        try {
          if (Money.parseMinor(value ?? '') < 0) return store.strings.t('invalidAmount');
          return null;
        } on FormatException {
          return store.strings.t('invalidAmount');
        }
      };

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _deadline = DateTime(picked.year, picked.month, picked.day, 18));
  }

  Future<void> _continue(AppStore store) async {
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      var customerId = _customerId;
      if (_newCustomer) {
        customerId = await store.database.createCustomer(name: _customerName.text, phone: _customerPhone.text, note: _customerNote.text);
      }
      final orderId = await store.database.createOrder(
        customerId: customerId!,
        deviceCategory: _category,
        deviceName: _deviceName.text,
        problem: _problem.text,
        conditionNote: _condition.text,
        serialNumber: _serial.text,
        priority: _priority,
        deadline: _deadline,
        estimateMinor: Money.parseMinor(_estimate.text),
        depositMinor: Money.parseMinor(_deposit.text),
        paymentMethod: _method,
        internalNote: _internalNote.text,
      );
      await store.refresh();
      if (!mounted) return;
      showMessage(context, store.strings.t('orderCreated'));
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)));
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) showMessage(context, store.strings.t('errorSave'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 12),
          Expanded(child: Text(value.isEmpty ? '—' : value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}
