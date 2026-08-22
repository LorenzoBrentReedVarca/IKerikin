import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../domain/models.dart';

/// Authentication contract consumed by the application layer.
abstract interface class AuthRepository {
  Stream<AppUser?> watchUser();
  Future<AppUser> signIn(String email, String password);
  Future<AppUser> register(String name, String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> resendVerification(String email);
  Future<void> signOut();
}

/// Supabase authentication implementation with local preview support.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._preferences);

  final SupabaseClient? _client;
  final SharedPreferences _preferences;
  static const _localUserKey = 'local_user';

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName:
          user.userMetadata?['display_name'] as String? ??
          user.email?.split('@').first ??
          'Parent',
      role: UserRole.values.firstWhere(
        (role) => role.name == user.userMetadata?['role'],
        orElse: () => UserRole.parent,
      ),
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
    );
  }

  @override
  Stream<AppUser?> watchUser() async* {
    if (_client == null) {
      final data = _preferences.getString(_localUserKey);
      yield data == null
          ? null
          : AppUser.fromJson(jsonDecode(data) as Map<String, dynamic>);
      return;
    }
    yield _mapUser(_client.auth.currentUser);
    yield* _client.auth.onAuthStateChange.map(
      (event) => _mapUser(event.session?.user),
    );
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    if (_client == null) {
      if (email.trim().isEmpty || password.length < 6) {
        throw const AuthException(
          'Enter a valid email and a password of at least 6 characters.',
        );
      }
      final user = AppUser(
        id: const Uuid().v5(
          '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
          email.trim().toLowerCase(),
        ),
        email: email.trim(),
        displayName: email.split('@').first,
      );
      await _preferences.setString(_localUserKey, jsonEncode(user.toJson()));
      return user;
    }
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = _mapUser(response.user);
    if (user == null) throw const AuthException('Unable to sign in.');
    return user;
  }

  @override
  Future<AppUser> register(String name, String email, String password) async {
    if (name.trim().length < 2 || !email.contains('@') || password.length < 8) {
      throw const AuthException(
        'Use a valid name, email, and password of at least 8 characters.',
      );
    }
    if (_client == null) {
      final user = AppUser(
        id: const Uuid().v5(
          '6ba7b811-9dad-11d1-80b4-00c04fd430c8',
          email.trim().toLowerCase(),
        ),
        email: email.trim(),
        displayName: name.trim(),
      );
      await _preferences.setString(_localUserKey, jsonEncode(user.toJson()));
      return user;
    }
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: AppConfig.redirectUrl,
      data: {'display_name': name.trim(), 'role': UserRole.parent.name},
    );
    final user = _mapUser(response.user);
    if (user == null)
      throw const AuthException('Unable to create your account.');
    return user;
  }

  @override
  Future<void> signInWithGoogle() async {
    if (_client == null) {
      throw const AuthException(
        'Google sign-in requires Supabase configuration.',
      );
    }
    final opened = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.redirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!opened) throw const AuthException('Could not open Google sign-in.');
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@'))
      throw const AuthException('Enter a valid email address.');
    if (_client != null) {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: AppConfig.redirectUrl,
      );
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    if (_client != null) {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: AppConfig.redirectUrl,
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _preferences.remove(_localUserKey);
    await _client?.auth.signOut();
  }
}

/// Child profile persistence contract.
abstract interface class ChildRepository {
  Future<List<ChildProfile>> getChildren(String parentId);
  Stream<List<ChildProfile>> watchChildren(String parentId);
  Future<ChildProfile> save(ChildProfile child);
  Future<void> delete(String id);
  Future<String> uploadPhoto(String childId, Uint8List bytes, String extension);
}

/// Supabase child repository with JSON offline cache.
class SupabaseChildRepository implements ChildRepository {
  SupabaseChildRepository(this._client, this._preferences);
  final SupabaseClient? _client;
  final SharedPreferences _preferences;
  static const _cacheKey = 'children_cache';

  Future<List<ChildProfile>> _readCache() async {
    final data = _preferences.getString(_cacheKey);
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map(
          (item) =>
              ChildProfile.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> _writeCache(List<ChildProfile> children) =>
      _preferences.setString(
        _cacheKey,
        jsonEncode(children.map((child) => child.toJson()).toList()),
      );

  @override
  Future<List<ChildProfile>> getChildren(String parentId) async {
    if (_client == null) return _readCache();
    try {
      final rows = await _client
          .from('children')
          .select()
          .eq('parent_id', parentId)
          .order('created_at');
      final children = rows.map(ChildProfile.fromJson).toList();
      await _writeCache(children);
      return children;
    } catch (_) {
      return _readCache();
    }
  }

  @override
  Stream<List<ChildProfile>> watchChildren(String parentId) async* {
    yield await getChildren(parentId);
    if (_client != null) {
      yield* _client
          .from('children')
          .stream(primaryKey: ['id'])
          .eq('parent_id', parentId)
          .order('created_at')
          .map((rows) => rows.map(ChildProfile.fromJson).toList())
          .asyncMap((children) async {
            await _writeCache(children);
            return children;
          });
    }
  }

  @override
  Future<ChildProfile> save(ChildProfile child) async {
    if (_client != null) {
      final row = await _client
          .from('children')
          .upsert(child.toJson())
          .select()
          .single();
      return ChildProfile.fromJson(row);
    }
    final children = await _readCache();
    final index = children.indexWhere((item) => item.id == child.id);
    if (index < 0) {
      children.add(child);
    } else {
      children[index] = child;
    }
    await _writeCache(children);
    return child;
  }

  @override
  Future<void> delete(String id) async {
    if (_client != null) await _client.from('children').delete().eq('id', id);
    final children = await _readCache()
      ..removeWhere((item) => item.id == id);
    await _writeCache(children);
  }

  @override
  Future<String> uploadPhoto(
    String childId,
    Uint8List bytes,
    String extension,
  ) async {
    if (_client == null) return '';
    final path = '${_client.auth.currentUser!.id}/$childId.$extension';
    await _client.storage
        .from('child-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$extension',
          ),
        );
    return _client.storage.from('child-photos').getPublicUrl(path);
  }
}

/// Swappable AI generation provider contract.
abstract interface class AiLessonProvider {
  Future<LessonContent> generate(LessonRequest request, ChildProfile child);
}

/// Secure Supabase Edge Function AI provider.
class SupabaseAiLessonProvider implements AiLessonProvider {
  const SupabaseAiLessonProvider(this._client);
  final SupabaseClient _client;

  @override
  Future<LessonContent> generate(
    LessonRequest request,
    ChildProfile child,
  ) async {
    final response = await _client.functions.invoke(
      AppConfig.aiFunctionName,
      body: {'request': request.toJson(), 'child': child.toJson()},
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Lesson service returned status ${response.status}.');
    }
    return LessonContent.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

/// AI 3D model generation contract consumed by lesson playback screens.
abstract interface class AiVideoProvider {
  Future<VideoGeneration> create(Lesson lesson, ChildProfile child);
  Future<VideoGeneration> getStatus(String videoId);
}

/// Supabase Edge Function adapter that keeps the Meshy API key off-device.
class SupabaseAiVideoProvider implements AiVideoProvider {
  const SupabaseAiVideoProvider(this._client);

  final SupabaseClient _client;

  Future<VideoGeneration> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      AppConfig.videoFunctionName,
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception('Video service returned status ${response.status}.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] is String) throw Exception(data['error']);
    return VideoGeneration.fromJson(data);
  }

  @override
  Future<VideoGeneration> create(Lesson lesson, ChildProfile child) => _invoke({
    'action': 'create',
    'lesson_id': lesson.id,
    'title': lesson.content.title,
    'summary': lesson.content.summary,
    'story': lesson.content.story,
    'child_preferences': {
      'interests': child.interests,
      'learning_styles': child.learningStyles,
      'preferred_language': child.preferredLanguage,
    },
  });

  @override
  Future<VideoGeneration> getStatus(String videoId) =>
      _invoke({'action': 'status', 'video_id': videoId});
}

/// Swappable animated lesson-video generation contract.
///
/// The Flutter app never talks to a video provider (e.g. Runway) directly —
/// implementations must proxy through a Supabase Edge Function so provider
/// API keys stay server-side. Swapping providers only requires a new
/// implementation of this interface (or changing the Edge Function's
/// internal provider), never a UI change.
abstract interface class VideoGenerationService {
  /// Starts (or resumes) rendering every scene of a lesson's video script.
  Future<VideoGenerationJob> startJob(Lesson lesson, ChildProfile child);

  /// Fetches the latest aggregate job + per-scene status.
  Future<VideoGenerationJob> getJob(String jobId);

  /// Re-queues failed scenes of an existing job without losing completed ones.
  Future<VideoGenerationJob> retryJob(String jobId, List<VideoScene> scenes);
}

/// Supabase Edge Function adapter for the Runway-backed video pipeline.
///
/// The Edge Function (`generate-video-scenes`) owns the actual provider
/// integration and the `RUNWAY_API_KEY` secret; this class only proxies
/// requests and normalizes responses into [VideoGenerationJob].
class SupabaseVideoGenerationService implements VideoGenerationService {
  const SupabaseVideoGenerationService(this._client);
  final SupabaseClient _client;

  static const _functionName = 'generate-video-scenes';

  Future<VideoGenerationJob> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke(
      _functionName,
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      throw Exception(
        'Video generation service returned status ${response.status}.',
      );
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] is String) throw Exception(data['error']);
    final scenes = (data['scenes'] as List? ?? const [])
        .map(
          (item) => GeneratedVideoScene.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return VideoGenerationJob.fromJson(
      Map<String, dynamic>.from(data['job'] as Map),
      scenes: scenes,
    );
  }

  @override
  Future<VideoGenerationJob> startJob(Lesson lesson, ChildProfile child) =>
      _invoke({
        'action': 'create',
        'lesson_id': lesson.id,
        'child_id': child.id,
        'scenes': lesson.content.videoScript.map((s) => s.toJson()).toList(),
      });

  @override
  Future<VideoGenerationJob> getJob(String jobId) =>
      _invoke({'action': 'status', 'job_id': jobId});

  @override
  Future<VideoGenerationJob> retryJob(String jobId, List<VideoScene> scenes) =>
      _invoke({
        'action': 'retry',
        'job_id': jobId,
        'scenes': scenes.map((s) => s.toJson()).toList(),
      });
}

/// Persists and retrieves animated lesson video job state.
abstract interface class VideoJobRepository {
  Future<VideoGenerationJob?> getJobForLesson(String lessonId);
  Stream<VideoGenerationJob?> watchJobForLesson(String lessonId);
  Future<VideoGenerationJob> startGeneration(Lesson lesson, ChildProfile child);
  Future<VideoGenerationJob> retry(String jobId, List<VideoScene> scenes);
}

/// Supabase-backed job repository built on [VideoGenerationService].
class SupabaseVideoJobRepository implements VideoJobRepository {
  SupabaseVideoJobRepository(this._client, this._service);
  final SupabaseClient? _client;
  final VideoGenerationService _service;

  Future<List<GeneratedVideoScene>> _scenesForJob(String jobId) async {
    if (_client == null) return const [];
    final rows = await _client
        .from('generated_video_scenes')
        .select()
        .eq('job_id', jobId)
        .order('scene_number');
    return rows.map(GeneratedVideoScene.fromJson).toList();
  }

  @override
  Future<VideoGenerationJob?> getJobForLesson(String lessonId) async {
    if (_client == null) return null;
    final rows = await _client
        .from('video_generation_jobs')
        .select()
        .eq('lesson_id', lessonId)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final job = Map<String, dynamic>.from(rows.first as Map);
    return VideoGenerationJob.fromJson(job, scenes: await _scenesForJob(job['id'] as String));
  }

  @override
  Stream<VideoGenerationJob?> watchJobForLesson(String lessonId) async* {
    yield await getJobForLesson(lessonId);
    if (_client == null) return;
    yield* _client
        .from('video_generation_jobs')
        .stream(primaryKey: ['id'])
        .eq('lesson_id', lessonId)
        .order('created_at')
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final job = Map<String, dynamic>.from(rows.last);
          return VideoGenerationJob.fromJson(
            job,
            scenes: await _scenesForJob(job['id'] as String),
          );
        });
  }

  @override
  Future<VideoGenerationJob> startGeneration(
    Lesson lesson,
    ChildProfile child,
  ) => _service.startJob(lesson, child);

  @override
  Future<VideoGenerationJob> retry(String jobId, List<VideoScene> scenes) =>
      _service.retryJob(jobId, scenes);
}


class LocalEducationalProvider implements AiLessonProvider {
  const LocalEducationalProvider();

  @override
  Future<LessonContent> generate(
    LessonRequest request,
    ChildProfile child,
  ) async {
    final interest = child.interests.isEmpty
        ? 'favorite things'
        : child.interests.first.toLowerCase();
    final goal = request.goal.trim();
    final name = child.name;
    return LessonContent(
      title: '$name Learns About $goal',
      summary:
          'A ${request.durationMinutes}-minute ${request.difficulty.name} lesson that uses $interest to help $name practice $goal.',
      story:
          '$name discovered a bright learning trail filled with $interest. At each stop, $name practiced $goal by looking carefully, listening, and trying one small step at a time. When a step felt difficult, $name took a calm breath and asked for help. By the end of the trail, $name had practiced three times and proudly said, “I can learn at my own pace!”',
      flashcards: [
        Flashcard(front: 'What are we learning?', back: goal),
        const Flashcard(
          front: 'What can I do when learning feels hard?',
          back: 'Pause, breathe, and ask for help.',
        ),
        Flashcard(
          front: 'What helps $name learn?',
          back: 'Practice one small step at a time.',
        ),
      ],
      quiz: [
        QuizQuestion(
          question: 'What is today’s learning goal?',
          options: [goal, 'Skip practice', 'Rush quickly'],
          correctIndex: 0,
          explanation: 'Today we are practicing $goal.',
        ),
        const QuizQuestion(
          question: 'What should you do when a task feels difficult?',
          options: ['Give up', 'Breathe and ask for help', 'Hide'],
          correctIndex: 1,
          explanation:
              'A calm breath and help from a trusted adult make learning easier.',
        ),
      ],
      memoryGame: [
        ActivityPair(left: goal, right: 'Today’s goal'),
        const ActivityPair(left: 'Calm breath', right: 'Helps me focus'),
        const ActivityPair(left: 'Practice', right: 'Helps me improve'),
      ],
      matchingActivity: [
        const ActivityPair(left: 'Eyes', right: 'Look'),
        const ActivityPair(left: 'Ears', right: 'Listen'),
        ActivityPair(left: 'Small steps', right: 'Learn $goal'),
      ],
      dailyActivity:
          'Invite $name to practice $goal with three familiar objects related to $interest. Praise effort after every attempt and stop before frustration builds.',
      parentTips: [
        'Use short, concrete instructions and allow extra processing time.',
        'Praise effort specifically: “You kept trying even when it was hard.”',
        'Repeat this activity in a familiar routine and follow $name’s sensory needs.',
      ],
    );
  }
}

/// Lesson persistence and generation contract.
abstract interface class LessonRepository {
  Future<List<Lesson>> getLessons(String childId);
  Future<Lesson> generate(LessonRequest request, ChildProfile child);
  Future<void> recordCompletion(
    String lessonId,
    String childId,
    int score,
    int minutes,
  );
}

/// Supabase lesson repository with resilient local caching.
class SupabaseLessonRepository implements LessonRepository {
  SupabaseLessonRepository(this._client, this._preferences, this._ai);
  final SupabaseClient? _client;
  final SharedPreferences _preferences;
  final AiLessonProvider _ai;
  static const _cacheKey = 'lessons_cache';

  List<Lesson> _readCache() {
    final data = _preferences.getString(_cacheKey);
    if (data == null) return [];
    return (jsonDecode(data) as List)
        .map((item) => Lesson.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _writeCache(List<Lesson> lessons) => _preferences.setString(
    _cacheKey,
    jsonEncode(lessons.map((lesson) => lesson.toJson()).toList()),
  );

  @override
  Future<List<Lesson>> getLessons(String childId) async {
    if (_client != null) {
      try {
        final rows = await _client
            .from('lessons')
            .select()
            .eq('child_id', childId)
            .order('created_at', ascending: false);
        final lessons = rows.map(Lesson.fromJson).toList();
        final all = _readCache()
          ..removeWhere((item) => item.childId == childId);
        await _writeCache([...all, ...lessons]);
        return lessons;
      } catch (_) {}
    }
    return _readCache().where((lesson) => lesson.childId == childId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Lesson> generate(LessonRequest request, ChildProfile child) async {
    if (_client != null) {
      await _client.from('lesson_requests').insert(request.toJson());
    }
    final content = await _ai.generate(request, child);
    final lesson = Lesson(
      id: const Uuid().v4(),
      childId: child.id,
      request: request,
      content: content,
      status: LessonStatus.completed,
      createdAt: DateTime.now(),
    );
    if (_client != null) await _client.from('lessons').insert(lesson.toJson());
    final cache = _readCache()..insert(0, lesson);
    await _writeCache(cache);
    return lesson;
  }

  @override
  Future<void> recordCompletion(
    String lessonId,
    String childId,
    int score,
    int minutes,
  ) async {
    final event = {
      'lesson_id': lessonId,
      'child_id': childId,
      'quiz_score': score,
      'time_spent_minutes': minutes,
      'completed_at': DateTime.now().toIso8601String(),
    };
    if (_client != null) {
      await _client.from('lesson_progress').insert(event);
    } else {
      final events =
          jsonDecode(_preferences.getString('progress_events') ?? '[]') as List;
      events.add(event);
      await _preferences.setString('progress_events', jsonEncode(events));
    }
  }
}

/// Progress reporting contract.
abstract interface class ProgressRepository {
  Future<ProgressSummary> getSummary(String childId);
}

/// Aggregates progress from Supabase or local completion events.
class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(this._client, this._preferences);
  final SupabaseClient? _client;
  final SharedPreferences _preferences;

  @override
  Future<ProgressSummary> getSummary(String childId) async {
    List<Map<String, dynamic>> events;
    if (_client != null) {
      events = await _client
          .from('lesson_progress')
          .select()
          .eq('child_id', childId);
    } else {
      events =
          (jsonDecode(_preferences.getString('progress_events') ?? '[]')
                  as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((item) => item['child_id'] == childId)
              .toList();
    }
    final scores = events
        .map((item) => item['quiz_score'] as int? ?? 0)
        .toList();
    final minutes = events.fold<int>(
      0,
      (sum, item) => sum + (item['time_spent_minutes'] as int? ?? 0),
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekly = List<int>.filled(7, 0);
    final monthly = List<int>.filled(4, 0);
    var completedToday = 0;
    for (final event in events) {
      final date =
          DateTime.tryParse(event['completed_at'] as String? ?? '') ?? now;
      if (DateTime(date.year, date.month, date.day) == today) {
        completedToday++;
      }
      final dayDiff = now.difference(date).inDays;
      if (dayDiff < 7)
        weekly[6 - dayDiff.clamp(0, 6)] +=
            event['time_spent_minutes'] as int? ?? 0;
      final weekDiff = dayDiff ~/ 7;
      if (weekDiff < 4) monthly[3 - weekDiff.clamp(0, 3)]++;
    }
    final xp = events.length * 100;
    return ProgressSummary(
      completedLessons: events.length,
      completedToday: completedToday,
      averageQuizScore: scores.isEmpty
          ? 0
          : scores.reduce((a, b) => a + b) / scores.length,
      timeSpentMinutes: minutes,
      xp: xp,
      coins: events.length * 20,
      streakDays: _calculateStreak(events, now),
      badges: [
        if (events.isNotEmpty) 'First Step',
        if (events.length >= 5) 'Curious Learner',
        if (events.length >= 10) 'Learning Champion',
        if (scores.any((score) => score == 100)) 'Quiz Star',
      ],
      weeklyMinutes: weekly,
      monthlyCompletions: monthly,
    );
  }

  int _calculateStreak(List<Map<String, dynamic>> events, DateTime now) {
    final days = events
        .map((item) => DateTime.tryParse(item['completed_at'] as String? ?? ''))
        .whereType<DateTime>()
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    var streak = 0;
    var day = DateTime(now.year, now.month, now.day);
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

/// Administrative data access contract.
abstract interface class AdminRepository {
  Future<AdminMetrics> getMetrics();
  Future<List<Map<String, dynamic>>> getRecords(String table);
  Future<void> deleteRecord(String table, String id);
}

/// Restricted Supabase administration implementation.
class SupabaseAdminRepository implements AdminRepository {
  const SupabaseAdminRepository(this._client);
  final SupabaseClient? _client;

  @override
  Future<AdminMetrics> getMetrics() async {
    if (_client == null) {
      return const AdminMetrics(
        users: 1,
        children: 0,
        lessons: 0,
        completedLessons: 0,
        openReports: 0,
      );
    }
    final result = await _client.rpc('admin_dashboard_metrics');
    final data = Map<String, dynamic>.from(result as Map);
    return AdminMetrics(
      users: data['users'] as int? ?? 0,
      children: data['children'] as int? ?? 0,
      lessons: data['lessons'] as int? ?? 0,
      completedLessons: data['completed_lessons'] as int? ?? 0,
      openReports: data['open_reports'] as int? ?? 0,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getRecords(String table) async {
    if (_client == null) return [];
    final allowed = {
      'profiles',
      'children',
      'reports',
      'lessons',
      'categories',
    };
    if (!allowed.contains(table)) throw ArgumentError.value(table, 'table');
    return await _client.from(table).select().limit(100);
  }

  @override
  Future<void> deleteRecord(String table, String id) async {
    final allowed = {'children', 'reports', 'lessons', 'categories'};
    if (!allowed.contains(table)) throw ArgumentError.value(table, 'table');
    await _client?.from(table).delete().eq('id', id);
  }
}

/// Word lookup contract used by the vocabulary explorer.
abstract interface class DictionaryRepository {
  Future<WordDefinition> lookup(String word);
}

/// Client for the free, keyless Dictionary API (https://dictionaryapi.dev).
class FreeDictionaryRepository implements DictionaryRepository {
  const FreeDictionaryRepository(this._client);
  final http.Client _client;

  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  @override
  Future<WordDefinition> lookup(String word) async {
    final trimmed = word.trim().toLowerCase();
    if (trimmed.isEmpty) {
      throw const FormatException('Enter a word to look up.');
    }
    final uri = Uri.parse('$_baseUrl/${Uri.encodeComponent(trimmed)}');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) {
      throw Exception('No definition found for "$trimmed".');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Dictionary service returned status ${response.statusCode}.',
      );
    }
    final entries = jsonDecode(response.body) as List;
    if (entries.isEmpty) {
      throw Exception('No definition found for "$trimmed".');
    }
    return WordDefinition.fromJson(
      Map<String, dynamic>.from(entries.first as Map),
    );
  }
}
