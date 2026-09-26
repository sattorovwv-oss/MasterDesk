import 'package:flutter/material.dart';

import '../core/app_strings.dart';
import '../models/entities.dart';
import 'app_database.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.database);

  final AppDatabase database;
  late WorkshopSettings settings;
  List<RepairOrder> orders = const [];
  List<Customer> customers = const [];
  List<Part> parts = const [];
  Map<String, int> dashboard = const {
    'active': 0,
    'ready': 0,
    'overdue': 0,
    'todayMinor': 0,
  };
  bool loading = true;

  String get localeCode => settings.localeCode;
  AppStrings get strings => AppStrings(localeCode);
  ThemeMode get themeMode => switch (settings.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> initialize() async {
    settings = await database.getSettings();
    await refresh();
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final values = await Future.wait([
      database.getOrders(),
      database.getCustomers(),
      database.getParts(),
      database.getDashboard(),
    ]);
    orders = values[0] as List<RepairOrder>;
    customers = values[1] as List<Customer>;
    parts = values[2] as List<Part>;
    dashboard = values[3] as Map<String, int>;
    settings = await database.getSettings();
    notifyListeners();
  }

  Future<void> completeOnboarding({
    required String name,
    required String phone,
    required String address,
    required String currency,
  }) async {
    await database.saveSettings(
      name: name,
      phone: phone,
      address: address,
      currency: currency,
      onboardingDone: true,
    );
    await refresh();
  }

  Future<void> setLocale(String locale) async {
    await database.saveSettings(localeCode: locale);
    settings = await database.getSettings();
    notifyListeners();
  }

  Future<void> setThemeMode(String mode) async {
    await database.saveSettings(themeMode: mode);
    settings = await database.getSettings();
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({
    required AppStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing');
    return scope!.notifier!;
  }
}
