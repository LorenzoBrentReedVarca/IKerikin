import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/providers.dart';
import 'core/localization/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget configuring theme, localization, accessibility, and routing.
class IKeriKinApp extends ConsumerWidget {
  const IKeriKinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'IKeriKin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(settings),
      darkTheme: AppTheme.dark(settings),
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.largeFonts ? 1.25 : 1),
          ),
          child: child!,
        );
      },
      routerConfig: router,
    );
  }
}
