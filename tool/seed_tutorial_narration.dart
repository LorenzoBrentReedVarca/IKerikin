/// Renders the guided tour's narration audio into Supabase storage.
///
/// The tour plays pre-rendered `.wav` files so narration starts instantly and
/// costs nothing per play. Those files have to exist, though: a Supabase
/// project whose `lesson-videos/tutorial/` folder is empty falls back to the
/// robotic on-device voice, with nothing in the app to say why. Run this once
/// per project — and again whenever the wording in `tutorial_script.dart`
/// changes, since the audio is rendered from exactly those words.
///
///   dart run tool/seed_tutorial_narration.dart \
///     --email you@example.com --password '...'
///
/// Options:
///   --url         Supabase project URL   (default: SUPABASE_URL env, else the
///                                         project baked into app_config.dart)
///   --anon-key    Supabase anon key      (default: SUPABASE_ANON_KEY env)
///   --email       Account to sign in as  (default: SUPABASE_EMAIL env)
///   --password    That account's password(default: SUPABASE_PASSWORD env)
///   --only        Comma-separated slugs to render instead of all
///   --dry-run     List what would be rendered, call nothing
///
/// Any signed-in account works: migration 011 lets authenticated users write
/// under the `tutorial/` prefix, since the narration is shared app content
/// rather than any one child's.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:ikerikin/application/tutorial_script.dart';

const _defaultUrl = 'https://pnienrjbdopfkedfeuhn.supabase.co';
const _functionName = 'generate-tutorial-narration';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);

  final url = (options['url'] ?? _env('SUPABASE_URL') ?? _defaultUrl)
      .replaceAll(RegExp(r'/+$'), '');
  final anonKey = options['anon-key'] ?? _env('SUPABASE_ANON_KEY');
  final email = options['email'] ?? _env('SUPABASE_EMAIL');
  final password = options['password'] ?? _env('SUPABASE_PASSWORD');
  final dryRun = options.containsKey('dry-run');

  final only = options['only']
      ?.split(',')
      .map((slug) => slug.trim())
      .where((slug) => slug.isNotEmpty)
      .toSet();
  final steps = only == null
      ? tutorialSteps
      : tutorialSteps.where((s) => only.contains(s.audioSlug)).toList();

  if (steps.isEmpty) {
    _fail('No steps matched --only. Known slugs: '
        '${tutorialSteps.map((s) => s.audioSlug).join(', ')}');
  }

  stdout.writeln('Project : $url');
  stdout.writeln('Bucket  : $tutorialNarrationBucket/$tutorialNarrationFolder');
  stdout.writeln('Steps   : ${steps.length} of ${tutorialSteps.length}');
  stdout.writeln('');

  if (dryRun) {
    for (final step in steps) {
      stdout.writeln('  ${step.audioSlug.padRight(16)} -> '
          '${tutorialNarrationPath(step.audioSlug)}');
      stdout.writeln('      ${step.body}');
    }
    stdout.writeln('\nDry run: nothing was rendered.');
    return;
  }

  if (anonKey == null || email == null || password == null) {
    _fail('Missing credentials. Supply --anon-key, --email and --password '
        '(or set SUPABASE_ANON_KEY, SUPABASE_EMAIL, SUPABASE_PASSWORD).');
  }

  final client = http.Client();
  try {
    final token = await _signIn(client, url, anonKey, email, password);
    var rendered = 0;
    var failed = 0;

    for (final step in steps) {
      stdout.write('  ${step.audioSlug.padRight(16)} ');
      try {
        final publicUrl = await _renderStep(
          client,
          url: url,
          anonKey: anonKey,
          token: token,
          step: step,
        );
        stdout.writeln('ok  $publicUrl');
        rendered++;
      } catch (error) {
        stdout.writeln('FAILED  $error');
        failed++;
      }
    }

    stdout.writeln('\n$rendered rendered, $failed failed.');
    if (failed > 0) exitCode = 1;
  } finally {
    client.close();
  }
}

/// Exchanges a password for an access token the Edge Function will accept.
Future<String> _signIn(
  http.Client client,
  String url,
  String anonKey,
  String email,
  String password,
) async {
  final response = await client.post(
    Uri.parse('$url/auth/v1/token?grant_type=password'),
    headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  if (response.statusCode != 200) {
    _fail('Sign-in failed (${response.statusCode}): ${response.body}');
  }
  final token =
      (jsonDecode(response.body) as Map<String, dynamic>)['access_token'];
  if (token is! String) _fail('Sign-in returned no access token.');
  return token;
}

/// Synthesizes one step and returns the public URL of the stored audio.
Future<String> _renderStep(
  http.Client client, {
  required String url,
  required String anonKey,
  required String token,
  required TutorialStep step,
}) async {
  final response = await client.post(
    Uri.parse('$url/functions/v1/$_functionName'),
    headers: {
      'apikey': anonKey,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'step_id': step.audioSlug, 'text': step.body}),
  );
  final decoded = response.body.isEmpty
      ? const <String, dynamic>{}
      : jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(decoded['error'] ?? 'status ${response.statusCode}');
  }
  final narrationUrl = decoded['narration_url'];
  if (narrationUrl is! String) throw Exception('no narration_url in response');
  return narrationUrl;
}

Map<String, String> _parseArgs(List<String> args) {
  final parsed = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final name = arg.substring(2);
    if (name == 'dry-run') {
      parsed[name] = 'true';
    } else if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      parsed[name] = args[++i];
    } else {
      _fail('Option --$name needs a value.');
    }
  }
  return parsed;
}

String? _env(String name) {
  final value = Platform.environment[name];
  return (value == null || value.isEmpty) ? null : value;
}

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}
