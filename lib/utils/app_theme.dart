import 'package:flutter/material.dart';
import '../widgets/app_ui.dart';

abstract final class AppTheme {
  static const primary = Color(0xFF7935C8);
  static const accent = Color(0xFFB976FF);
  static const lavender = Color(0xFFF4ECFF);
  static const ink = Color(0xFF191919);
  static const muted = Color(0xFF717171);
  static const background = Color(0xFFF7F7F7);
  static const neutral = Color(0xFFF1F1F1);
  static const border = Color(0xFFEAEAEA);
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: neutral,
        surfaceContainer: neutral,
        surfaceContainerHigh: border,
        surfaceTint: Colors.transparent,
        onSurface: ink,
        onSurfaceVariant: muted,
        outlineVariant: border);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));
    final base = ThemeData(
        useMaterial3: true, colorScheme: scheme, fontFamily: 'AppRoboto');
    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CalmPageTransitions(),
        TargetPlatform.iOS: CalmPageTransitions(),
        TargetPlatform.windows: CalmPageTransitions(),
        TargetPlatform.macOS: CalmPageTransitions(),
        TargetPlatform.linux: CalmPageTransitions(),
      }),
      hoverColor: primary.withValues(alpha: .04),
      splashFactory: InkRipple.splashFactory,
      expansionTileTheme: const ExpansionTileThemeData(
          iconColor: primary, collapsedIconColor: muted),
      listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          iconColor: muted,
          minVerticalPadding: 12),
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
          elevation: 1.5,
          shadowColor: Colors.black.withValues(alpha: .08),
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: neutral,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: primary, width: 2))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: ink,
                  minimumSize: const Size(48, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: shape,
                  textStyle: const TextStyle(
                      fontFamily: 'AppRoboto',
                      fontWeight: FontWeight.w700,
                      fontSize: 14))
              .copyWith(
                  animationDuration: const Duration(milliseconds: 180),
                  elevation: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? 2 : 0),
                  shadowColor:
                      WidgetStatePropertyAll(accent.withValues(alpha: .18)),
                  overlayColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.pressed)
                          ? primary.withValues(alpha: .12)
                          : states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)
                              ? Colors.white.withValues(alpha: .16)
                              : Colors.transparent))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  shape: shape)
              .copyWith(
                  animationDuration: const Duration(milliseconds: 180),
                  elevation: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.hovered) ? 2 : 0),
                  shadowColor:
                      WidgetStatePropertyAll(primary.withValues(alpha: .18)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: ink,
                  minimumSize: const Size(48, 48),
                  shape: shape,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  side: const BorderSide(color: border))
              .copyWith(
                  animationDuration: const Duration(milliseconds: 180),
                  side: WidgetStateProperty.resolveWith((states) => BorderSide(
                      color: states.contains(WidgetState.focused) ||
                              states.contains(WidgetState.hovered)
                          ? primary.withValues(alpha: .4)
                          : border)))),
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
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: lavender,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected) ? primary : muted)),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: 'AppRoboto',
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? primary : muted)),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 72),
      chipTheme: base.chipTheme.copyWith(
          side: BorderSide.none,
          backgroundColor: Colors.white,
          selectedColor: lavender,
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          labelStyle: const TextStyle(
              fontFamily: 'AppRoboto',
              fontSize: 13,
              color: muted,
              fontWeight: FontWeight.w500),
          shape: const StadiumBorder()),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          shape: shape),
    );
  }
}
