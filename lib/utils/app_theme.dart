import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const primary = Color(0xFF6544C0);
  static const ink = Color(0xFF242139);
  static const muted = Color(0xFF666278);
  static const background = Color(0xFFF6F5FA);
  static const border = Color(0xFFE4E1ED);
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        outlineVariant: border);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final base = ThemeData(
        useMaterial3: true, colorScheme: scheme, fontFamily: 'AppRoboto');
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontFamily: 'AppRoboto',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ink)),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: border))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primary, width: 2))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: shape,
              textStyle: const TextStyle(
                  fontFamily: 'AppRoboto',
                  fontWeight: FontWeight.w700,
                  fontSize: 14))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(48, 48),
              shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              side: const BorderSide(color: border))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48), shape: shape)),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Color(0xFFEDE7FA),
          height: 76),
      chipTheme: base.chipTheme.copyWith(
          side: const BorderSide(color: border),
          selectedColor: const Color(0xFFEDE7FA),
          shape: const StadiumBorder()),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          shape: shape),
    );
  }
}
