import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';

import 'app.dart';
import 'application/providers.dart';
import 'core/config/app_config.dart';

/// Initializes local and cloud services before rendering IKeriKin.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // video_player has no native Windows/Linux implementation of its own;
  // this registers media_kit (libmpv) as the platform implementation there
  // so lesson video playback works on desktop, not just web/Android/iOS.
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);
  await AppConfig.initialize();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const IKeriKinApp(),
    ),
  );
}
