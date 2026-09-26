import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/app_theme.dart';
import '../data/app_store.dart';
import '../screens/main_shell.dart';
import '../screens/onboarding_screen.dart';

class MasterDeskApp extends StatelessWidget {
  const MasterDeskApp({required this.store, super.key});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'MasterDesk',
          locale: Locale(store.localeCode),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: store.themeMode,
          home: store.settings.onboardingDone
              ? const MainShell()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}
