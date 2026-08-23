import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/accessibility/accessibility_settings.dart';
import '../core/config/app_config.dart';
import '../data/repositories.dart';
import '../domain/models.dart';

/// Overridden during bootstrap with the initialized preferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw StateError('SharedPreferences must be initialized before runApp.'),
);

/// Provides the live Supabase client used throughout the app.
final supabaseClientProvider = Provider((ref) => AppConfig.supabase);

/// Provides authentication persistence.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// Emits the current session and subsequent authentication changes.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);

/// Provides child profile persistence.
final childRepositoryProvider = Provider<ChildRepository>(
  (ref) => SupabaseChildRepository(ref.watch(supabaseClientProvider)),
);

/// Generates lesson text (story, flashcards, quiz, memory/matching games,
/// parent tips) via the Gemini-backed `generate-lesson` Edge Function.
final aiLessonProvider = Provider<AiLessonProvider>(
  (ref) => SupabaseAiLessonProvider(ref.watch(supabaseClientProvider)),
);

/// Provides the swappable animated lesson-video generation service.
final videoGenerationServiceProvider = Provider<VideoGenerationService>(
  (ref) => SupabaseVideoGenerationService(ref.watch(supabaseClientProvider)),
);

/// Provides animated lesson video job persistence and orchestration.
final videoJobRepositoryProvider = Provider<VideoJobRepository>(
  (ref) => SupabaseVideoJobRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(videoGenerationServiceProvider),
  ),
);

/// Streams the animated video generation job (if any) for a lesson.
final videoJobProvider = StreamProvider.family<VideoGenerationJob?, String>(
  (ref, lessonId) =>
      ref.watch(videoJobRepositoryProvider).watchJobForLesson(lessonId),
);

/// Provides lesson generation and persistence.
final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => SupabaseLessonRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(aiLessonProvider),
  ),
);

/// Provides learning progress aggregation.
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SupabaseProgressRepository(ref.watch(supabaseClientProvider)),
);

/// Provides restricted administrative data access.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider)),
);

/// Shared HTTP client for outbound REST calls to third-party APIs.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Provides vocabulary lookups from the Free Dictionary API.
final dictionaryRepositoryProvider = Provider<DictionaryRepository>(
  (ref) => FreeDictionaryRepository(ref.watch(httpClientProvider)),
);

/// Streams a parent's child profiles.
final childrenProvider = StreamProvider.family<List<ChildProfile>, String>(
  (ref, parentId) => ref.watch(childRepositoryProvider).watchChildren(parentId),
);

/// Loads lessons belonging to a child.
final lessonsProvider = FutureProvider.family<List<Lesson>, String>(
  (ref, childId) => ref.watch(lessonRepositoryProvider).getLessons(childId),
);

/// Loads a child's aggregate progress.
final progressProvider = FutureProvider.family<ProgressSummary, String>(
  (ref, childId) => ref.watch(progressRepositoryProvider).getSummary(childId),
);

/// Loads administrator dashboard metrics.
final adminMetricsProvider = FutureProvider<AdminMetrics>(
  (ref) => ref.watch(adminRepositoryProvider).getMetrics(),
);

/// Executes authentication commands and exposes their busy state.
class AuthController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> _run(Future<void> Function() operation) async {
    state = true;
    try {
      await operation();
      ref.invalidate(authStateProvider);
    } finally {
      state = false;
    }
  }

  Future<void> signIn(String email, String password) => _run(
    () async => ref.read(authRepositoryProvider).signIn(email, password),
  );

  Future<void> register(String name, String email, String password) => _run(
    () async =>
        ref.read(authRepositoryProvider).register(name, email, password),
  );

  Future<void> google() =>
      _run(ref.read(authRepositoryProvider).signInWithGoogle);

  Future<void> resetPassword(String email) =>
      _run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));

  Future<void> resendVerification(String email) =>
      _run(() => ref.read(authRepositoryProvider).resendVerification(email));

  Future<void> signOut() => _run(ref.read(authRepositoryProvider).signOut);
}

/// Provides authentication command state.
final authControllerProvider = NotifierProvider<AuthController, bool>(
  AuthController.new,
);

/// Stores the active child ID across app launches.
class SelectedChildController extends Notifier<String?> {
  static const _key = 'selected_child_id';

  @override
  String? build() => ref.read(sharedPreferencesProvider).getString(_key);

  Future<void> select(String? childId) async {
    state = childId;
    final preferences = ref.read(sharedPreferencesProvider);
    if (childId == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, childId);
    }
  }
}

/// Provides the active child ID.
final selectedChildProvider =
    NotifierProvider<SelectedChildController, String?>(
      SelectedChildController.new,
    );

/// Persists and exposes app-wide accessibility preferences.
class AccessibilityController extends Notifier<AccessibilitySettings> {
  static const _key = 'accessibility_settings';

  @override
  AccessibilitySettings build() {
    final value = ref.read(sharedPreferencesProvider).getString(_key);
    if (value == null) return const AccessibilitySettings();
    return AccessibilitySettings.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
  }

  Future<void> update(AccessibilitySettings settings) async {
    state = settings;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(settings.toJson()));
  }
}

/// Provides accessibility settings.
final accessibilityProvider =
    NotifierProvider<AccessibilityController, AccessibilitySettings>(
      AccessibilityController.new,
    );

/// Persists and exposes the chosen interface locale.
class LocaleController extends Notifier<Locale> {
  static const _key = 'locale';

  @override
  Locale build() =>
      Locale(ref.read(sharedPreferencesProvider).getString(_key) ?? 'en');

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, locale.languageCode);
  }
}

/// Provides the active interface locale.
final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

/// Coordinates child profile mutations.
class ChildController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<ChildProfile> save({
    required String parentId,
    required ChildProfile child,
    Uint8List? photoBytes,
    String photoExtension = 'jpg',
  }) async {
    state = true;
    try {
      var updated = child;
      if (photoBytes != null) {
        final url = await ref
            .read(childRepositoryProvider)
            .uploadPhoto(child.id, photoBytes, photoExtension);
        if (url.isNotEmpty) updated = child.copyWith(photoUrl: url);
      }
      final saved = await ref.read(childRepositoryProvider).save(updated);
      ref.invalidate(childrenProvider(parentId));
      await ref.read(selectedChildProvider.notifier).select(saved.id);
      return saved;
    } finally {
      state = false;
    }
  }

  Future<void> delete(String parentId, String childId) async {
    state = true;
    try {
      await ref.read(childRepositoryProvider).delete(childId);
      ref.invalidate(childrenProvider(parentId));
      if (ref.read(selectedChildProvider) == childId) {
        await ref.read(selectedChildProvider.notifier).select(null);
      }
    } finally {
      state = false;
    }
  }

  /// Creates a stable ID for a new child before optional photo upload.
  String createId() => const Uuid().v4();
}

/// Provides child mutation state.
final childControllerProvider = NotifierProvider<ChildController, bool>(
  ChildController.new,
);

/// Looks up word definitions from the Free Dictionary API and exposes
/// loading, data, and error states to the vocabulary explorer screen.
class WordLookupController extends AsyncNotifier<WordDefinition?> {
  @override
  Future<WordDefinition?> build() async => null;

  Future<void> lookup(String word) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(dictionaryRepositoryProvider).lookup(word),
    );
  }
}

/// Provides the active word lookup state.
final wordLookupControllerProvider =
    AsyncNotifierProvider<WordLookupController, WordDefinition?>(
      WordLookupController.new,
    );

/// Coordinates lesson generation and completion mutations.
class LessonController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<Lesson> generate(LessonRequest request, ChildProfile child) async {
    state = true;
    try {
      final lesson = await ref
          .read(lessonRepositoryProvider)
          .generate(request, child);
      ref.invalidate(lessonsProvider(child.id));
      return lesson;
    } finally {
      state = false;
    }
  }

  Future<void> complete(Lesson lesson, int score, int minutes) async {
    state = true;
    try {
      await ref
          .read(lessonRepositoryProvider)
          .recordCompletion(lesson.id, lesson.childId, score, minutes);
      ref.invalidate(progressProvider(lesson.childId));
    } finally {
      state = false;
    }
  }
}

/// Provides lesson mutation state.
final lessonControllerProvider = NotifierProvider<LessonController, bool>(
  LessonController.new,
);

/// Coordinates animated lesson video generation and retry mutations.
class VideoJobController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<VideoGenerationJob?> start(Lesson lesson, ChildProfile child) async {
    final repository = ref.read(videoJobRepositoryProvider);
    state = true;
    try {
      final job = await repository.startGeneration(lesson, child);
      ref.invalidate(videoJobProvider(lesson.id));
      return job;
    } finally {
      state = false;
    }
  }

  Future<VideoGenerationJob?> retry(Lesson lesson, String jobId) async {
    final repository = ref.read(videoJobRepositoryProvider);
    state = true;
    try {
      final job = await repository.retry(jobId, lesson.content.videoScript);
      ref.invalidate(videoJobProvider(lesson.id));
      return job;
    } finally {
      state = false;
    }
  }
}

/// Provides animated lesson video mutation state.
final videoJobControllerProvider = NotifierProvider<VideoJobController, bool>(
  VideoJobController.new,
);
