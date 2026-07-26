import 'package:flutter/foundation.dart';

/// Roles supported by IKeriKin.
enum UserRole { parent, child, administrator }

/// Supported lesson difficulty levels.
enum LessonDifficulty { easy, medium, challenging }

/// Lifecycle status of a generated lesson.
enum LessonStatus { pending, generating, completed, failed }

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
  const Flashcard({required this.front, required this.back});
  final String front;
  final String back;
  factory Flashcard.fromJson(Map<String, dynamic> json) => Flashcard(
    front: json['front'] as String? ?? '',
    back: json['back'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {'front': front, 'back': back};
}

/// A quiz question and its answer choices.
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
    question: json['question'] as String? ?? '',
    options: List<String>.from(json['options'] as List? ?? const []),
    correctIndex: json['correct_index'] as int? ?? 0,
    explanation: json['explanation'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correct_index': correctIndex,
    'explanation': explanation,
  };
}

/// A pair used by memory and matching activities.
@immutable
class ActivityPair {
  const ActivityPair({required this.left, required this.right});
  final String left;
  final String right;
  factory ActivityPair.fromJson(Map<String, dynamic> json) => ActivityPair(
    left: json['left'] as String? ?? '',
    right: json['right'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {'left': left, 'right': right};
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
  };
}

/// Current state of an asynchronous AI video render.
@immutable
class VideoGeneration {
  const VideoGeneration({
    required this.id,
    required this.status,
    required this.progress,
    this.error,
  });

  final String id;
  final String status;
  final int progress;
  final String? error;

  bool get isComplete => status == 'completed';
  bool get isFailed => status == 'failed';

  factory VideoGeneration.fromJson(Map<String, dynamic> json) =>
      VideoGeneration(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'queued',
        progress: (json['progress'] as num?)?.round() ?? 0,
        error: (json['error'] as Map?)?['message'] as String?,
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
  });

  final String id;
  final String childId;
  final String goal;
  final LessonDifficulty difficulty;
  final String language;
  final int durationMinutes;
  final String additionalNotes;
  final DateTime createdAt;

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
}
