import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized build-time configuration for IKeriKin.
///
/// Supabase is IKeriKin's only backend: every auth, data, and AI call goes
/// through the live project below. The anon key is safe to ship in client
/// builds by design (Postgres RLS is the real access boundary) — it can
/// still be overridden with `--dart-define` for a different environment,
/// but there is no offline/local fallback mode anymore.
abstract final class AppConfig {
  /// Supabase project URL. Override with `--dart-define=SUPABASE_URL=...`.
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pnienrjbdopfkedfeuhn.supabase.co',
  );

  /// Supabase anonymous key. Override with `--dart-define=SUPABASE_ANON_KEY=...`.
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBuaWVucmpiZG9wZmtlZGZldWhuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ5OTE0ODcsImV4cCI6MjEwMDU2NzQ4N30.LRJga1y-mBut9QtVmUhIR4RZv5ikB8tqN7x5m3Nf2_4',
  );

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

  /// Initializes the Supabase client. Called once at app startup.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  /// The live Supabase client used for every auth, data, and AI call.
  static SupabaseClient get supabase => Supabase.instance.client;
}
