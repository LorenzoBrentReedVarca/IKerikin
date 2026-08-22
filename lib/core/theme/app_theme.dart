import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../accessibility/accessibility_settings.dart';

/// Builds IKeriKin's accessible Material 3 themes.
abstract final class AppTheme {
  static const _seed = Color(0xFF6C4CF1);
  static const _darkSeed = Color(0xFFB9A0FF);

  /// Signature accent colors used for gradients, blobs, and hero surfaces.
  static const brandViolet = Color(0xFF7C5CFF);
  static const brandPink = Color(0xFFFF6FB5);
  static const brandCoral = Color(0xFFFF8A65);
  static const brandTeal = Color(0xFF3ED6C6);
  static const brandAmber = Color(0xFFFFC24B);

  /// Shared corner radius so cards, ink ripples, and buttons stay aligned.
  static const radius = 8.0;

  /// Soft ambient shadow used to gently lift hero surfaces and tiles.
  static List<BoxShadow> softShadow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      BoxShadow(
        color: scheme.shadow.withValues(alpha: .05),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: scheme.primary.withValues(alpha: .08),
        blurRadius: 24,
        offset: const Offset(0, 10),
        spreadRadius: -8,
      ),
    ];
  }

  /// Signature gradient used behind hero marks such as the animated logo.
  static LinearGradient heroGradient(BuildContext context) => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandViolet, brandPink, brandCoral],
  );

  /// Soft aurora gradient used behind entire screens for depth.
  static LinearGradient auroraGradient(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [
              scheme.surface,
              Color.alphaBlend(brandViolet.withValues(alpha: .06), scheme.surface),
              Color.alphaBlend(brandTeal.withValues(alpha: .04), scheme.surface),
            ]
          : [
              Color.alphaBlend(brandViolet.withValues(alpha: .035), scheme.surface),
              scheme.surface,
              Color.alphaBlend(brandTeal.withValues(alpha: .035), scheme.surface),
            ],
    );
  }

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
    final buttonHeight = settings.largeButtons ? 60.0 : 50.0;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Keeps touch targets generous on desktop and web, where Flutter would
      // otherwise shrink controls below comfortable tap sizes.
      visualDensity: VisualDensity.standard,
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
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
        shadowColor: scheme.primary.withValues(alpha: .08),
        surfaceTintColor: Colors.transparent,
        color: brightness == Brightness.light
            ? Colors.white.withValues(alpha: .92)
            : scheme.surfaceContainerLowest,
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: brightness == Brightness.light
                ? scheme.outlineVariant.withValues(alpha: .35)
                : scheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: shape,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: baseText.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: baseText.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white.withValues(alpha: .85)
            : scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: baseText.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(buttonHeight),
          shape: shape,
          elevation: 0,
          shadowColor: scheme.primary.withValues(alpha: .35),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, buttonHeight),
          shape: shape,
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(0, settings.largeButtons ? 52 : 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size.square(settings.largeButtons ? 56 : 48),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: Size(0, buttonHeight),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: shape,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        borderRadius: BorderRadius.circular(8),
        linearMinHeight: 8,
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: baseText.titleSmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: settings.largeButtons ? 88 : 74,
        elevation: 0,
        backgroundColor: brightness == Brightness.light
            ? Colors.white.withValues(alpha: .92)
            : scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: .16),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => baseText.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: baseText.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: baseText.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
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
