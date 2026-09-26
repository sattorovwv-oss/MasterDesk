import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../widgets/common.dart';
import 'auxiliary_screens.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final s = store.strings;
    final entries = [
      (Icons.payments_outlined, s.t('finance'), const FinanceScreen()),
      (Icons.bar_chart_outlined, s.t('reports'), const ReportsScreen()),
      (Icons.task_alt_outlined, s.t('tasks'), const TasksScreen()),
      (Icons.badge_outlined, s.t('employees'), const EmployeesScreen()),
      (Icons.home_repair_service_outlined, s.t('services'), const ServicesScreen()),
      (Icons.settings_outlined, s.t('settings'), const SettingsScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.t('more'), style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(children: [
        PageContainer(
          maxWidth: 800,
          child: Column(children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/masterdesk_icon.png', width: 52, height: 52, fit: BoxFit.cover)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(store.settings.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text('MasterDesk · ${store.settings.currency}', style: Theme.of(context).textTheme.bodySmall)])),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            ...entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), leading: Icon(entry.$1), title: Text(entry.$2, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => entry.$3)))),
                )),
          ]),
        ),
      ]),
    );
  }
}
