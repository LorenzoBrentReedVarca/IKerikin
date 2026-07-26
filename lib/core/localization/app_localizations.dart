import 'package:flutter/widgets.dart';

/// Lightweight built-in localization for core interface strings.
class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('fil')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  static const _values = <String, Map<String, String>>{
    'en': {
      'appName': 'IKeriKin',
      'tagline': 'I Care for Your Kin',
      'home': 'Home',
      'children': 'Children',
      'create': 'Create',
      'progress': 'Progress',
      'settings': 'Settings',
    },
    'fil': {
      'appName': 'IKeriKin',
      'tagline': 'Mahalaga sa Amin ang Iyong Pamilya',
      'home': 'Tahanan',
      'children': 'Mga Bata',
      'create': 'Gumawa',
      'progress': 'Pag-unlad',
      'settings': 'Mga Setting',
    },
  };

  String get appName => _get('appName');
  String get tagline => _get('tagline');
  String get home => _get('home');
  String get children => _get('children');
  String get create => _get('create');
  String get progress => _get('progress');
  String get settings => _get('settings');

  String _get(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key]!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
