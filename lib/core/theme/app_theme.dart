import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../accessibility/accessibility_settings.dart';

/// Builds IKeriKin's accessible Material 3 themes.
abstract final class AppTheme {
  static const _seed = Color(0xFF6738D1);
  static const _darkSeed = Color(0xFFB9A0FF);

  static ThemeData light(AccessibilitySettings settings) =>
      _build(Brightness.light, settings);

  static ThemeData dark(AccessibilitySettings settings) =>
      _build(Brightness.dark, settings);

  static ThemeData _build(
    Brightness brightness,
    AccessibilitySettings settings,
  ) {
    final contrast = settings.highContrast;
    final scheme = ColorScheme.fromSeed(
      seedColor: brightness == Brightness.light ? _seed : _darkSeed,
      brightness: brightness,
      contrastLevel: contrast ? 1 : 0.15,
    );
    final baseText = settings.dyslexiaFont
        ? GoogleFonts.atkinsonHyperlegibleTextTheme()
        : GoogleFonts.nunitoTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        titleTextStyle: baseText.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(settings.largeButtons ? 64 : 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: settings.largeButtons ? 88 : 72,
        elevation: 2,
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          baseText.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      pageTransitionsTheme: settings.reducedMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _NoAnimationTransitions(),
                TargetPlatform.iOS: _NoAnimationTransitions(),
              },
            )
          : const PageTransitionsTheme(),
    );
  }
}

class _NoAnimationTransitions extends PageTransitionsBuilder {
  const _NoAnimationTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
