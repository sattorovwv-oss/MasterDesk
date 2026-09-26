import 'package:flutter/material.dart';

import '../data/app_store.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  int _step = 0;
  String _currency = 'TJS';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.build_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 38),
                ),
                const SizedBox(height: 16),
                Text('MasterDesk', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(s.t('subtitle'), style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 28),
                LinearProgressIndicator(value: (_step + 1) / 2),
                const SizedBox(height: 24),
                Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: _step == 0 ? _languageStep(store) : _workshopStep(store))),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : () => _next(store),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_step == 0 ? s.t('continue') : s.t('start')),
                  ),
                ),
                const Spacer(),
                const Text('NEXVIRO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageStep(AppStore store) => Column(
        key: const ValueKey(0),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(store.strings.t('language'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ru', label: Text('Русский'), icon: Icon(Icons.language)),
              ButtonSegment(value: 'en', label: Text('English'), icon: Icon(Icons.language)),
            ],
            selected: {store.localeCode},
            onSelectionChanged: (value) => store.setLocale(value.first),
          ),
        ],
      );

  Widget _workshopStep(AppStore store) {
    final s = store.strings;
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.t('workshop'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: '${s.t('workshopName')} *', prefixIcon: const Icon(Icons.storefront_outlined)),
            validator: (value) => value == null || value.trim().isEmpty ? s.t('required') : null,
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: s.t('phone'), prefixIcon: const Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: InputDecoration(labelText: s.t('address'), prefixIcon: const Icon(Icons.location_on_outlined))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: InputDecoration(labelText: s.t('currency'), prefixIcon: const Icon(Icons.payments_outlined)),
            items: ['TJS', 'RUB', 'USD', 'EUR'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setState(() => _currency = value ?? 'TJS'),
          ),
        ]),
      ),
    );
  }

  Future<void> _next(AppStore store) async {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await store.completeOnboarding(name: _name.text.trim(), phone: _phone.text.trim(), address: _address.text.trim(), currency: _currency);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
