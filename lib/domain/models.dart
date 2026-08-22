import 'package:flutter/foundation.dart';

/// Roles supported by IKeriKin.
enum UserRole { parent, child, administrator }

/// Supported lesson difficulty levels.
enum LessonDifficulty { easy, medium, challenging }

/// Lifecycle status of a generated lesson.
enum LessonStatus { pending, generating, completed, failed }

/// Lifecycle status of an animated scene/lesson video render.
enum VideoGenerationStatus { queued, generating, processing, completed, failed }

/// Immutable application user profile.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.role = UserRole.parent,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    email: json['email'] as String? ?? '',
    displayName: json['display_name'] as String? ?? 'Parent',
    role: UserRole.values.firstWhere(
      (value) => value.name == json['role'],
      orElse: () => UserRole.parent,
    ),
    avatarUrl: json['avatar_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'role': role.name,
    'avatar_url': avatarUrl,
  };
}

/// Immutable child learning profile.
@immutable
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.parentId,
    required this.name,
    required this.birthday,
    required this.gender,
    required this.preferredLanguage,
    required this.disabilities,
    required this.challenges,
    required this.interests,
    required this.learningStyles,
    this.photoUrl,
    this.createdAt,
  });

  final String id;
  final String parentId;
  final String name;
  final DateTime birthday;
  final String gender;
  final String preferredLanguage;
  final List<String> disabilities;
  final List<String> challenges;
  final List<String> interests;
  final List<String> learningStyles;
  final String? photoUrl;
  final DateTime? createdAt;

  /// Current age, calculated from the birthday.
  int get age {
    final now = DateTime.now();
    var years = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      years--;
    }
    return years.clamp(0, 120);
  }

  ChildProfile copyWith({
    String? id,
    String? parentId,
    String? name,
    DateTime? birthday,
    String? gender,
    String? preferredLanguage,
    List<String>? disabilities,
    List<String>? challenges,
    List<String>? interests,
    List<String>? learningStyles,
    String? photoUrl,
    DateTime? createdAt,
  }) => ChildProfile(
    id: id ?? this.id,
    parentId: parentId ?? this.parentId,
    name: name ?? this.name,
    birthday: birthday ?? this.birthday,
    gender: gender ?? this.gender,
    preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    disabilities: disabilities ?? this.disabilities,
    challenges: challenges ?? this.challenges,
    interests: interests ?? this.interests,
    learningStyles: learningStyles ?? this.learningStyles,
    photoUrl: photoUrl ?? this.photoUrl,
    createdAt: createdAt ?? this.createdAt,
  );

  factory ChildProfile.fromJson(Map<String, dynamic> json) => ChildProfile(
    id: json['id'] as String,
    parentId: json['parent_id'] as String,
    name: json['name'] as String,
    birthday: DateTime.parse(json['birthday'] as String),
    gender: json['gender'] as String? ?? 'Prefer not to say',
    preferredLanguage: json['preferred_language'] as String? ?? 'English',
    disabilities: List<String>.from(json['disabilities'] as List? ?? const []),
    challenges: List<String>.from(json['challenges'] as List? ?? const []),
    interests: List<String>.from(json['interests'] as List? ?? const []),
    learningStyles: List<String>.from(
      json['learning_styles'] as List? ?? const [],
    ),
    photoUrl: json['photo_url'] as String?,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parent_id': parentId,
    'name': name,
    'birthday': birthday.toIso8601String().split('T').first,
    'gender': gender,
    'preferred_language': preferredLanguage,
    'disabilities': disabilities,
    'challenges': challenges,
    'interests': interests,
    'learning_styles': learningStyles,
    'photo_url': photoUrl,
  };
}

/// A single flashcard in an AI-generated lesson.
@immutable
class Flashcard {
  const Flashcard({
    required this.front,
    required this.back,
    this.imageDescription = '',
  });
  final String front;
  final String back;
  /// Optional visual description a parent/illustrator can use as a fallback image prompt.
  final String imageDescription;
  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
    front: json['front'] as String? ?? '',
    back: json['back'] as String? ?? '',
    imageDescription: json['image_description'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'front': front,
    'back': back,
    'image_description': imageDescription,
  };
}

/// A quiz question and its answer choices.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.difficulty = '',
  });
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty;
  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question: json['question'] as String? ?? '',
    options: List<String>.from(json['options'] as List? ?? const []),
    correctIndex: json['correct_index'] as int? ?? 0,
    explanation: json['explanation'] as String? ?? '',
    difficulty: json['difficulty'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correct_index': correctIndex,
    'explanation': explanation,
    'difficulty': difficulty,
  };
}

/// A pair used by memory and matching activities.
@immutable
class ActivityPair {
  const ActivityPair({
    required this.left,
    required this.right,
    this.imageDescription = '',
    this.educationalConnection = '',
  });
  final String left;
  final String right;
  final String imageDescription;
  final String educationalConnection;
  factory ActivityPair.fromJson(Map<String, dynamic> json) => ActivityPair(
    left: json['left'] as String? ?? '',
    right: json['right'] as String? ?? '',
    imageDescription: json['image_description'] as String? ?? '',
    educationalConnection: json['educational_connection'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'left': left,
    'right': right,
    'image_description': imageDescription,
    'educational_connection': educationalConnection,
  };
}

/// A single scene in an AI-generated animated video script.
@immutable
class VideoScene {
  const VideoScene({
    required this.sceneNumber,
    required this.durationSeconds,
    required this.narration,
    required this.visualPrompt,
    required this.educationalObjective,
  });
  final int sceneNumber;
  final int durationSeconds;
  final String narration;
  /// Prompt sent to the video generation provider (e.g. Runway).
  final String visualPrompt;
  final String educationalObjective;

  factory VideoScene.fromJson(Map<String, dynamic> json) => VideoScene(
    sceneNumber: json['scene_number'] as int? ?? 1,
    durationSeconds: json['duration_seconds'] as int? ?? 8,
    narration: json['narration'] as String? ?? '',
    visualPrompt: json['visual_prompt'] as String? ?? '',
    educationalObjective: json['educational_objective'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'scene_number': sceneNumber,
    'duration_seconds': durationSeconds,
    'narration': narration,
    'visual_prompt': visualPrompt,
    'educational_objective': educationalObjective,
  };
}

/// Structured educational content returned by an AI provider.
@immutable
class LessonContent {
  const LessonContent({
    required this.title,
    required this.summary,
    required this.story,
    required this.flashcards,
    required this.quiz,
    required this.memoryGame,
    required this.matchingActivity,
    required this.dailyActivity,
    required this.parentTips,
    this.objectives = const [],
    this.videoScript = const [],
  });

  final String title;
  final String summary;
  final String story;
  final List<Flashcard> flashcards;
  final List<QuizQuestion> quiz;
  final List<ActivityPair> memoryGame;
  final List<ActivityPair> matchingActivity;
  final String dailyActivity;
  final List<String> parentTips;
  /// Learning objectives the lesson targets.
  final List<String> objectives;
  /// Structured animated video script generated alongside the lesson.
  final List<VideoScene> videoScript;

  factory LessonContent.fromJson(Map<String, dynamic> json) => LessonContent(
    title: json['title'] as String? ?? 'Personalized Lesson',
    summary: json['summary'] as String? ?? '',
    story: json['story'] as String? ?? '',
    flashcards: (json['flashcards'] as List? ?? const [])
        .map(
          (item) => Flashcard.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    quiz: (json['quiz'] as List? ?? const [])
        .map(
          (item) =>
              QuizQuestion.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    memoryGame: (json['memory_game'] as List? ?? const [])
        .map(
          (item) =>
              ActivityPair.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    matchingActivity: (json['matching_activity'] as List? ?? const [])
        .map(
          (item) =>
              ActivityPair.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    dailyActivity: json['daily_activity'] as String? ?? '',
    parentTips: List<String>.from(json['parent_tips'] as List? ?? const []),
    objectives: List<String>.from(json['objectives'] as List? ?? const []),
    videoScript: (json['video_script'] as List? ?? const [])
        .map(
          (item) => VideoScene.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'story': story,
    'flashcards': flashcards.map((item) => item.toJson()).toList(),
    'quiz': quiz.map((item) => item.toJson()).toList(),
    'memory_game': memoryGame.map((item) => item.toJson()).toList(),
    'matching_activity': matchingActivity.map((item) => item.toJson()).toList(),
    'daily_activity': dailyActivity,
    'parent_tips': parentTips,
    'objectives': objectives,
    'video_script': videoScript.map((item) => item.toJson()).toList(),
  };
}

/// Current state of an asynchronous AI 3D model render.
@immutable
class VideoGeneration {
  const VideoGeneration({
    required this.id,
    required this.status,
    required this.progress,
    this.error,
    this.modelUrl,
  });

  final String id;
  final String status;
  final int progress;
  final String? error;
  final String? modelUrl;

  bool get isComplete => status == 'completed';
  bool get isFailed => status == 'failed';

  factory VideoGeneration.fromJson(Map<String, dynamic> json) =>
      VideoGeneration(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'queued',
        progress: (json['progress'] as num?)?.round() ?? 0,
        error: (json['error'] as Map?)?['message'] as String?,
        modelUrl: json['model_url'] as String?,
      );
}

/// Input parameters used to request a personalized lesson.
@immutable
class LessonRequest {
  const LessonRequest({
    required this.id,
    required this.childId,
    required this.goal,
    required this.difficulty,
    required this.language,
    required this.durationMinutes,
    required this.additionalNotes,
    required this.createdAt,
    this.videoDurationSeconds = 60,
    this.contentType = 'Story',
  });

  final String id;
  final String childId;
  final String goal;
  final LessonDifficulty difficulty;
  final String language;
  final int durationMinutes;
  final String additionalNotes;
  final DateTime createdAt;
  /// Requested animated video length: 60 (Quick Lesson), 180 (Learning Adventure), or 300 (Full Story) seconds.
  final int videoDurationSeconds;
  /// Story, Educational Adventure, Cartoon Lesson, or Interactive Lesson.
  final String contentType;

  factory LessonRequest.fromJson(Map<String, dynamic> json) => LessonRequest(
    id: json['id'] as String,
    childId: json['child_id'] as String,
    goal: json['goal'] as String,
    difficulty: LessonDifficulty.values.firstWhere(
      (value) => value.name == json['difficulty'],
      orElse: () => LessonDifficulty.easy,
    ),
    language: json['language'] as String? ?? 'English',
    durationMinutes: json['duration_minutes'] as int? ?? 15,
    additionalNotes: json['additional_notes'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    videoDurationSeconds: json['video_duration_seconds'] as int? ?? 60,
    contentType: json['content_type'] as String? ?? 'Story',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'child_id': childId,
    'goal': goal,
    'difficulty': difficulty.name,
    'language': language,
    'duration_minutes': durationMinutes,
    'additional_notes': additionalNotes,
    'created_at': createdAt.toIso8601String(),
    'video_duration_seconds': videoDurationSeconds,
    'content_type': contentType,
  };
}

/// A generated and persisted learning lesson.
@immutable
class Lesson {
  const Lesson({
    required this.id,
    required this.childId,
    required this.request,
    required this.content,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String childId;
  final LessonRequest request;
  final LessonContent content;
  final LessonStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    childId: json['child_id'] as String,
    request: LessonRequest.fromJson(
      Map<String, dynamic>.from(json['request_data'] as Map),
    ),
    content: LessonContent.fromJson(
      Map<String, dynamic>.from(json['content'] as Map? ?? const {}),
    ),
    status: LessonStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => LessonStatus.completed,
    ),
    createdAt: DateTime.parse(json['created_at'] as String),
    completedAt: DateTime.tryParse(json['completed_at'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'child_id': childId,
    'request_data': request.toJson(),
    'content': content.toJson(),
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };
}

/// Aggregated child progress displayed in dashboards.
@immutable
class ProgressSummary {
  const ProgressSummary({
    required this.completedLessons,
    required this.completedToday,
    required this.averageQuizScore,
    required this.timeSpentMinutes,
    required this.xp,
    required this.coins,
    required this.streakDays,
    required this.badges,
    required this.weeklyMinutes,
    required this.monthlyCompletions,
  });

  final int completedLessons;
  final int completedToday;
  final double averageQuizScore;
  final int timeSpentMinutes;
  final int xp;
  final int coins;
  final int streakDays;
  final List<String> badges;
  final List<int> weeklyMinutes;
  final List<int> monthlyCompletions;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) =>
      ProgressSummary(
        completedLessons: json['completed_lessons'] as int? ?? 0,
        completedToday: json['completed_today'] as int? ?? 0,
        averageQuizScore: (json['average_quiz_score'] as num? ?? 0).toDouble(),
        timeSpentMinutes: json['time_spent_minutes'] as int? ?? 0,
        xp: json['xp'] as int? ?? 0,
        coins: json['coins'] as int? ?? 0,
        streakDays: json['streak_days'] as int? ?? 0,
        badges: List<String>.from(json['badges'] as List? ?? const []),
        weeklyMinutes: List<int>.from(
          json['weekly_minutes'] as List? ?? const [0, 0, 0, 0, 0, 0, 0],
        ),
        monthlyCompletions: List<int>.from(
          json['monthly_completions'] as List? ?? const [0, 0, 0, 0],
        ),
      );
}

/// Admin overview metrics.
@immutable
class AdminMetrics {
  const AdminMetrics({
    required this.users,
    required this.children,
    required this.lessons,
    required this.completedLessons,
    required this.openReports,
  });
  final int users;
  final int children;
  final int lessons;
  final int completedLessons;
  final int openReports;
}

/// A single sense of a word returned by the Free Dictionary API.
@immutable
class WordMeaning {
  const WordMeaning({
    required this.partOfSpeech,
    required this.definitions,
    required this.examples,
  });

  final String partOfSpeech;
  final List<String> definitions;
  final List<String> examples;

  factory WordMeaning.fromJson(Map<String, dynamic> json) {
    final definitionEntries = (json['definitions'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return WordMeaning(
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      definitions: definitionEntries
          .map((entry) => entry['definition'] as String? ?? '')
          .where((definition) => definition.isNotEmpty)
          .toList(),
      examples: definitionEntries
          .map((entry) => entry['example'] as String?)
          .whereType<String>()
          .toList(),
    );
  }
}

/// A word lookup result from the Free Dictionary API
/// (https://dictionaryapi.dev), used by the vocabulary explorer.
@immutable
class WordDefinition {
  const WordDefinition({
    required this.word,
    required this.phonetic,
    required this.audioUrl,
    required this.meanings,
  });

  final String word;
  final String phonetic;
  final String? audioUrl;
  final List<WordMeaning> meanings;

  factory WordDefinition.fromJson(Map<String, dynamic> json) {
    final phonetics = (json['phonetics'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final audio = phonetics
        .map((entry) => entry['audio'] as String?)
        .firstWhere(
          (url) => url != null && url.isNotEmpty,
          orElse: () => null,
        );
    return WordDefinition(
      word: json['word'] as String? ?? '',
      phonetic:
          json['phonetic'] as String? ??
          (phonetics.isEmpty ? '' : phonetics.first['text'] as String? ?? ''),
      audioUrl: audio,
      meanings: (json['meanings'] as List? ?? const [])
          .map(
            (item) => WordMeaning.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

/// Canonical profile choices shared by forms and AI prompts.
abstract final class ProfileOptions {
  static const disabilities = [
    'Autism',
    'ADHD',
    'Down Syndrome',
    'Dyslexia',
    'Speech Delay',
    'Learning Disability',
    'Developmental Delay',
    'Cerebral Palsy',
    'Visual Impairment',
    'Hearing Impairment',
    'Other',
  ];
  static const challenges = [
    'Reading',
    'Writing',
    'Communication',
    'Memory',
    'Concentration',
    'Social Skills',
    'Math',
    'Behavior',
    'Motor Skills',
    'Hygiene',
    'Other',
  ];
  static const interests = [
    'Animals',
    'Dinosaurs',
    'Music',
    'Cars',
    'Princesses',
    'Superheroes',
    'Space',
    'Nature',
    'Art',
    'Books',
    'Sports',
    'Science',
    'Technology',
    'Cooking',
    'Other',
  ];
  static const learningStyles = [
    'Animated Videos',
    'Storybooks',
    'Games',
    'Flashcards',
    'Audio',
    'Visual',
    'Mixed',
  ];
  static const languages = ['English', 'Filipino', 'Cebuano'];

  /// Preferred AI-generated content presentation.
  static const contentTypes = [
    'Story',
    'Educational Adventure',
    'Cartoon Lesson',
    'Interactive Lesson',
  ];

  /// Maps a friendly video length label to its duration in seconds.
  static const videoDurations = <String, int>{
    'Quick Lesson (1 minute)': 60,
    'Learning Adventure (3 minutes)': 180,
    'Full Story (5 minutes)': 300,
  };
}

/// Parses a video generation status string, defaulting to [VideoGenerationStatus.queued].
VideoGenerationStatus parseVideoGenerationStatus(String? value) =>
    VideoGenerationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => VideoGenerationStatus.queued,
    );

/// The outcome of generating (or checking) a single animated scene.
@immutable
class VideoGenerationResult {
  const VideoGenerationResult({
    required this.sceneNumber,
    required this.status,
    this.providerJobId,
    this.videoUrl,
    this.errorMessage,
  });

  final int sceneNumber;
  final VideoGenerationStatus status;
  /// External provider (e.g. Runway) task/job identifier used for polling.
  final String? providerJobId;
  final String? videoUrl;
  final String? errorMessage;

  factory VideoGenerationResult.fromJson(Map<String, dynamic> json) =>
      VideoGenerationResult(
        sceneNumber: json['scene_number'] as int? ?? 1,
        status: parseVideoGenerationStatus(json['status'] as String?),
        providerJobId: json['provider_job_id'] as String?,
        videoUrl: json['video_url'] as String?,
        errorMessage: json['error_message'] as String?,
      );
}

/// A single persisted animated scene render tracked in `generated_video_scenes`.
@immutable
class GeneratedVideoScene {
  const GeneratedVideoScene({
    required this.id,
    required this.jobId,
    required this.lessonId,
    required this.childId,
    required this.sceneNumber,
    required this.provider,
    required this.status,
    this.providerJobId,
    this.videoUrl,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String jobId;
  final String lessonId;
  final String childId;
  final int sceneNumber;
  final String provider;
  final VideoGenerationStatus status;
  final String? providerJobId;
  final String? videoUrl;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory GeneratedVideoScene.fromJson(Map<String, dynamic> json) =>
      GeneratedVideoScene(
        id: json['id'] as String,
        jobId: json['job_id'] as String,
        lessonId: json['lesson_id'] as String,
        childId: json['child_id'] as String,
        sceneNumber: json['scene_number'] as int? ?? 1,
        provider: json['provider'] as String? ?? 'runway',
        status: parseVideoGenerationStatus(json['generation_status'] as String?),
        providerJobId: json['generation_job_id'] as String?,
        videoUrl: json['video_url'] as String?,
        errorMessage: json['error_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

/// The overall animated lesson video render, aggregating all of its scenes.
@immutable
class VideoGenerationJob {
  const VideoGenerationJob({
    required this.id,
    required this.lessonId,
    required this.childId,
    required this.provider,
    required this.status,
    this.videoUrl,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.scenes = const [],
  });

  final String id;
  final String lessonId;
  final String childId;
  final String provider;
  final VideoGenerationStatus status;
  /// Final combined lesson video URL, set once every scene completes.
  final String? videoUrl;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<GeneratedVideoScene> scenes;

  bool get isComplete => status == VideoGenerationStatus.completed;
  bool get isFailed => status == VideoGenerationStatus.failed;

  factory VideoGenerationJob.fromJson(
    Map<String, dynamic> json, {
    List<GeneratedVideoScene> scenes = const [],
  }) => VideoGenerationJob(
    id: json['id'] as String,
    lessonId: json['lesson_id'] as String,
    childId: json['child_id'] as String,
    provider: json['provider'] as String? ?? 'runway',
    status: parseVideoGenerationStatus(json['status'] as String?),
    videoUrl: json['video_url'] as String?,
    errorMessage: json['error_message'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    scenes: scenes,
  );
}

