import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Provides the optional configured Supabase client.
final supabaseClientProvider = Provider((ref) => AppConfig.supabase);

/// Provides authentication persistence.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Emits the current session and subsequent authentication changes.
final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);

/// Provides child profile persistence.
final childRepositoryProvider = Provider<ChildRepository>(
  (ref) => SupabaseChildRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Selects the cloud AI provider when configured and an offline provider otherwise.
final aiLessonProvider = Provider<AiLessonProvider>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null
      ? const LocalEducationalProvider()
      : SupabaseAiLessonProvider(client);
});

/// Provides cloud video generation when Supabase is configured.
final aiVideoProvider = Provider<AiVideoProvider?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAiVideoProvider(client);
});

/// Provides lesson generation and persistence.
final lessonRepositoryProvider = Provider<LessonRepository>(
  (ref) => SupabaseLessonRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(aiLessonProvider),
  ),
);

/// Provides learning progress aggregation.
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SupabaseProgressRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// Provides restricted administrative data access.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => SupabaseAdminRepository(ref.watch(supabaseClientProvider)),
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
