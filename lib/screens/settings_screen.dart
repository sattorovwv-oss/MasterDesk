import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../services/export_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(children: [
        PageContainer(
          maxWidth: 760,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(title: s.t('workshop')),
            Card(child: ListTile(leading: const Icon(Icons.storefront_outlined), title: Text(store.settings.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text([store.settings.phone, store.settings.address, store.settings.currency].where((e) => e.isNotEmpty).join(' · ')), trailing: const Icon(Icons.edit_outlined), onTap: _busy ? null : () => _editWorkshop(store))),
            const SizedBox(height: 24),
            SectionHeader(title: s.t('language')),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'ru', label: Text('Русский')), ButtonSegment(value: 'en', label: Text('English'))],
              selected: {store.localeCode},
              onSelectionChanged: _busy ? null : (value) => store.setLocale(value.first),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: s.t('appearance')),
            SegmentedButton<String>(
              segments: [ButtonSegment(value: 'system', label: Text(s.t('system')), icon: const Icon(Icons.settings_suggest_outlined)), ButtonSegment(value: 'light', label: Text(s.t('light')), icon: const Icon(Icons.light_mode_outlined)), ButtonSegment(value: 'dark', label: Text(s.t('dark')), icon: const Icon(Icons.dark_mode_outlined))],
              selected: {store.settings.themeMode},
              onSelectionChanged: _busy ? null : (value) => store.setThemeMode(value.first),
            ),
            const SizedBox(height: 24),
            SectionHeader(title: s.t('backup')),
            _SettingsTile(icon: Icons.backup_outlined, title: s.t('backup'), subtitle: s.isRu ? 'Создать файл со всеми рабочими данными' : 'Create a file with all workshop data', onTap: _busy ? null : () => _backup(store)),
            const SizedBox(height: 10),
            _SettingsTile(icon: Icons.restore_outlined, title: s.t('restore'), subtitle: s.isRu ? 'Текущие данные будут заменены после проверки файла' : 'Current data will be replaced after file validation', onTap: _busy ? null : () => _restore(store)),
            const SizedBox(height: 10),
            _SettingsTile(icon: Icons.table_view_outlined, title: s.t('exportCsv'), subtitle: s.isRu ? 'Таблица заказов для Excel' : 'Orders table for Excel', onTap: _busy ? null : () => _csv(store)),
            const SizedBox(height: 24),
            SectionHeader(title: s.t('about')),
            Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/images/masterdesk_icon.png', width: 64, height: 64, fit: BoxFit.cover)),
              const SizedBox(height: 14),
              const Text('MasterDesk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(s.t('subtitle')),
              const SizedBox(height: 16),
              Text(s.t('developed'), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(s.t('developer')),
              Text(s.t('version'), style: Theme.of(context).textTheme.bodySmall),
            ]))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _editWorkshop(AppStore store) async {
    final name = TextEditingController(text: store.settings.name);
    final phone = TextEditingController(text: store.settings.phone);
    final address = TextEditingController(text: store.settings.address);
    final key = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(store.strings.t('workshop')),
      content: Form(key: key, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: name, decoration: InputDecoration(labelText: '${store.strings.t('workshopName')} *'), validator: (value) => value == null || value.trim().isEmpty ? store.strings.t('required') : null),
        const SizedBox(height: 12),
        TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: store.strings.t('phone'))),
        const SizedBox(height: 12),
        TextFormField(controller: address, decoration: InputDecoration(labelText: store.strings.t('address'))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () { if (key.currentState?.validate() ?? false) Navigator.pop(dialogContext, true); }, child: Text(store.strings.t('save')))],
    ));
    if (accepted == true) {
      await store.database.saveSettings(name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim());
      await store.refresh();
    }
    name.dispose(); phone.dispose(); address.dispose();
  }

  Future<void> _backup(AppStore store) async {
    setState(() => _busy = true);
    try {
      await ExportService.shareBackup(store.database);
      if (mounted) showMessage(context, store.strings.t('successBackup'));
    } catch (_) {
      if (mounted) showMessage(context, store.strings.isRu ? 'Не удалось создать резервную копию' : 'Could not create backup', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(AppStore store) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(store.strings.t('restore')),
      content: Text(store.strings.isRu ? 'После проверки файла текущие данные будут заменены. Продолжить?' : 'After validation, current data will be replaced. Continue?'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(store.strings.t('cancel'))), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(store.strings.t('continue')))],
    ));
    if (confirmed != true) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      await ExportService.restoreBackup(store.database, path);
      await store.refresh();
      if (mounted) showMessage(context, store.strings.t('successRestore'));
    } catch (_) {
      if (mounted) showMessage(context, store.strings.isRu ? 'Не удалось прочитать резервную копию' : "Couldn't read the backup", error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _csv(AppStore store) async {
    setState(() => _busy = true);
    try {
      await ExportService.shareOrdersCsv(store.orders, store.settings.currency, store.localeCode);
    } catch (_) {
      if (mounted) showMessage(context, store.strings.isRu ? 'Не удалось создать CSV' : 'Could not create CSV', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.all(12), leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}
