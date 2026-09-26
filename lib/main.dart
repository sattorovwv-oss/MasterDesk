import 'package:flutter/material.dart';

import 'app/masterdesk_app.dart';
import 'data/app_database.dart';
import 'data/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.open();
  final store = AppStore(database);
  await store.initialize();
  runApp(MasterDeskApp(store: store));
}
