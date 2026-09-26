import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const lightBackground = Color(0xFFF5F7FB);
  static const lightText = Color(0xFF142033);
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF131E30);
  static const darkText = Color(0xFFF1F5F9);

  static ThemeData light() => _theme(
        brightness: Brightness.light,
        primary: const Color(0xFF1D4ED8),
        background: lightBackground,
        surface: Colors.white,
        text: lightText,
        outline: const Color(0xFFD8E1EC),
      );

  static ThemeData dark() => _theme(
        brightness: Brightness.dark,
        primary: const Color(0xFF93C5FD),
        background: darkBackground,
        surface: darkSurface,
        text: darkText,
        outline: const Color(0xFF33445E),
      );

  static ThemeData _theme({
    required Brightness brightness,
    required Color primary,
    required Color background,
    required Color surface,
    required Color text,
    required Color outline,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      surface: surface,
      error: brightness == Brightness.light
          ? const Color(0xFFB91C1C)
          : const Color(0xFFFCA5A5),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: outline),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'DejaVuSans',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            bodyColor: text,
            displayColor: text,
            fontFamily: 'DejaVuSans',
          ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: brightness == Brightness.light ? 1 : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
