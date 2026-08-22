import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized build-time configuration for IKeriKin.
abstract final class AppConfig {
  /// Supabase project URL supplied with `--dart-define=SUPABASE_URL=...`.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Supabase anonymous key supplied with `--dart-define=SUPABASE_ANON_KEY=...`.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const _redirectUrlDefine = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'ph.ikerikin.ikerikin://auth-callback',
  );

  /// Public URL used by OAuth and password reset deep links.
  ///
  /// The custom app scheme only resolves on Android/iOS. On web there is no
  /// installed app to catch it, so redirects must land back on the site's own
  /// origin, which Supabase parses from the URL fragment automatically.
  static String get redirectUrl =>
      kIsWeb ? Uri.base.origin : _redirectUrlDefine;

  /// Edge Function name that safely calls the configured AI provider.
  static const aiFunctionName = String.fromEnvironment(
    'AI_FUNCTION_NAME',
    defaultValue: 'generate-lesson',
  );

  /// Edge Function that creates and proxies asynchronous AI video renders.
  static const videoFunctionName = String.fromEnvironment(
    'VIDEO_FUNCTION_NAME',
    defaultValue: 'generate-video',
  );

  /// Whether cloud services are configured for this build.
  static bool get hasSupabase =>
      supabaseUrl.startsWith('https://') && supabaseAnonKey.isNotEmpty;

  /// Initializes Supabase when credentials are available.
  static Future<void> initialize() async {
    if (hasSupabase) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    }
  }

  /// Returns the configured client or `null` in local preview mode.
  static SupabaseClient? get supabase =>
      hasSupabase ? Supabase.instance.client : null;
}
