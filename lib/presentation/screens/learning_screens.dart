import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../widgets/common_widgets.dart';

/// Resolves the active child from the authenticated parent's profiles.
ChildProfile? activeChild(WidgetRef ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final children = ref.watch(childrenProvider(user.id)).value ?? [];
  final selectedId = ref.watch(selectedChildProvider);
  return children.where((child) => child.id == selectedId).firstOrNull ??
      children.firstOrNull;
}

/// Personalized parent dashboard and child learning launchpad.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final childrenState = ref.watch(childrenProvider(user.id));
    return Scaffold(
      body: ResponsiveBody(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: childrenState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString()),
          data: (children) {
            if (children.isEmpty) {
              return EmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'Let’s begin together',
                message:
                    'Create a child profile to unlock personalized lessons, goals, and progress tracking.',
                action: FilledButton.icon(
                  onPressed: () => context.go('/children'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create profile'),
                ),
              );
            }
            final selectedId = ref.watch(selectedChildProvider);
            final child =
                children.where((item) => item.id == selectedId).firstOrNull ??
                children.first;
            final progress =
                ref.watch(progressProvider(child.id)).value ??
                const ProgressSummary(
                  completedLessons: 0,
                  completedToday: 0,
                  averageQuizScore: 0,
                  timeSpentMinutes: 0,
                  xp: 0,
                  coins: 0,
                  streakDays: 0,
                  badges: [],
                  weeklyMinutes: [0, 0, 0, 0, 0, 0, 0],
                  monthlyCompletions: [0, 0, 0, 0],
                );
            final lessons = ref.watch(lessonsProvider(child.id)).value ?? [];
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(lessonsProvider(child.id));
                ref.invalidate(progressProvider(child.id));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _HeaderCard(
                    userName: user.displayName,
                    child: child,
                    children: children,
                  ),
                  const SizedBox(height: 14),
                  Card(
                    color: const Color(0xFFFBF8FF),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE9E0FF),
                                child: Icon(Icons.track_changes_rounded),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Today's Goal",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const Text('Learn • Practice • Review'),
                                  ],
                                ),
                              ),
                              Text(
                                '${progress.completedToday.clamp(0, 3)} / 3',
                                style: const TextStyle(
                                  color: Color(0xFF6738D1),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress.completedToday.clamp(0, 3) / 3,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionHeading(
                    title: 'Continue Learning',
                    action: TextButton(
                      onPressed: () => context.go('/learn'),
                      child: const Text('View all'),
                    ),
                  ),
                  if (lessons.isEmpty)
                    EmptyState(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Create ${child.name}’s first lesson',
                      message:
                          'Choose a learning goal and IKeriKin will build personalized activities.',
                      action: FilledButton.icon(
                        onPressed: () => context.go('/create'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create lesson'),
                      ),
                    )
                  else
                    _LessonHeroTile(
                      title: lessons.first.content.title,
                      subtitle: lessons.first.content.summary,
                      onTap: () => context.push(
                        '/lesson/${lessons.first.id}',
                        extra: lessons.first,
                      ),
                    ),
                  const SizedBox(height: 14),
                  ResponsiveGrid(
                    minItemWidth: 120,
                    childAspectRatio: 1.25,
                    children: [
                      MetricCard(
                        icon: Icons.star_rounded,
                        value: '${progress.xp}',
                        label: 'XP',
                        color: Colors.amber,
                      ),
                      MetricCard(
                        icon: Icons.monetization_on_rounded,
                        value: '${progress.coins}',
                        label: 'Coins',
                        color: Colors.orange,
                      ),
                      MetricCard(
                        icon: Icons.local_fire_department_rounded,
                        value: '${progress.streakDays}',
                        label: 'Day streak',
                        color: Colors.deepOrange,
                      ),
                      MetricCard(
                        icon: Icons.workspace_premium_rounded,
                        value: '${progress.badges.length}',
                        label: 'Badges',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SectionHeading(
                    title: 'Recent Lessons',
                    action: TextButton(
                      onPressed: () => context.go('/learn'),
                      child: const Text('See all'),
                    ),
                  ),
                  if (lessons.isEmpty)
                    const Text('Lessons will appear here after you create one.')
                  else
                    ...lessons
                        .take(2)
                        .map(
                          (lesson) => _ActivityTile(
                            index: lessons.indexOf(lesson) + 1,
                            title: lesson.content.title,
                            subtitle:
                                '${lesson.request.difficulty.name} • ${lesson.request.durationMinutes} min',
                            buttonLabel: 'Start',
                            color: const Color(0xFFF3EEFF),
                            onTap: () => context.push(
                              '/lesson/${lesson.id}',
                              extra: lesson,
                            ),
                          ),
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /* Corrupted generated block retained temporarily for safe recovery.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final childrenState = ref.watch(childrenProvider(user.id));
    return Scaffold(
      body: ResponsiveBody(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: childrenState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString()),
          data: (children) {
            if (children.isEmpty)
              return EmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'Let’s begin together',
                message:
                    'Create a child profile to unlock personalized lessons, goals, and progress tracking.',
                action: FilledButton.icon(
                  onPressed: () => context.go('/children'),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create profile'),
                ),
              );
            final selectedId = ref.watch(selectedChildProvider);
            final child =
                children.where((item) => item.id == selectedId).firstOrNull ??
                children.first;
            final progress =
                ref.watch(progressProvider(child.id)).value ??
                const ProgressSummary(
                  completedLessons: 0,
                  completedToday: 0,
                  averageQuizScore: 0,
                  timeSpentMinutes: 0,
                  xp: 0,
                  coins: 0,
                  streakDays: 0,
                  badges: [],
                  weeklyMinutes: [0, 0, 0, 0, 0, 0, 0],
                  monthlyCompletions: [0, 0, 0, 0],
                      actions: [
                        IconButton(
                          onPressed: () => _tts.speak(content.summary),
                          tooltip: 'Read lesson objective',
                          icon: const Icon(Icons.volume_up_outlined),
                        ),
                      ],
                    ),
                    bottomNavigationBar: SafeArea(
                      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: FilledButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Complete Lesson'),
                    userName: user.displayName,
                    child: child,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Column(
                        children: [
                          Card(
                            color: const Color(0xFFF8F4FF),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                              const CircleAvatar(
                                  Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor: Color(0xFFE9E0FF),
                                        child: Icon(Icons.track_changes_rounded),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Learning Objective',
                                              style: TextStyle(fontWeight: FontWeight.w900),
                                            ),
                                            Text(content.summary),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(
                                        avatar: const Icon(Icons.menu_book_outlined, size: 18),
                                        label: const Text('Story + Activities'),
                                      ),
                                      Chip(
                                        avatar: const Icon(Icons.timer_outlined, size: 18),
                                        label: Text(
                                          '${widget.lesson.request.durationMinutes} minutes',
                                        ),
                                      ),
                                      const Chip(
                                        avatar: Icon(Icons.star_outline_rounded, size: 18),
                                        label: Text('100 XP'),
                                      ),
                                      const Chip(
                                        avatar: Icon(Icons.monetization_on_outlined, size: 18),
                                        label: Text('20 coins'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TabBar(
                            controller: _tabs,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: const [
                              Tab(icon: Icon(Icons.menu_book_rounded), text: 'Story'),
                              Tab(icon: Icon(Icons.style_rounded), text: 'Flashcards'),
                              Tab(icon: Icon(Icons.quiz_rounded), text: 'Quiz'),
                              Tab(icon: Icon(Icons.grid_view_rounded), text: 'Memory'),
                              Tab(icon: Icon(Icons.extension_rounded), text: 'Match'),
                              Tab(icon: Icon(Icons.lightbulb_rounded), text: 'Parent Tips'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TabBarView(
                              controller: _tabs,
                              children: [
                                ListView(
                                  children: [
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              content.title,
                                              style: Theme.of(context).textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              content.story,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(height: 1.65),
                                            ),
                                            const SizedBox(height: 12),
                                            TextButton.icon(
                                              onPressed: () => _tts.speak(content.story),
                                              icon: const Icon(Icons.volume_up_rounded),
                                              label: const Text('Listen to Story'),
                                            ),
                                          ],
                                        ),
                                      ),
                              Expanded(
                                  ],
                                  padding: const EdgeInsets.symmetric(
                                ListView.separated(
                                  itemCount: content.flashcards.length,
                                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                                  itemBuilder: (_, index) =>
                                      _FlipCard(card: content.flashcards[index]),
                                ),
                                ListView.builder(
                                  itemCount: content.quiz.length,
                                  itemBuilder: (context, index) {
                                    final question = content.quiz[index];
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${index + 1}. ${question.question}',
                                              style: Theme.of(context).textTheme.titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.w800),
                                            ),
                                            ...question.options.indexed.map(
                                              (option) => RadioListTile<int>(
                                                value: option.$1,
                                                groupValue: _answers[index],
                                                onChanged: (value) => setState(
                                                  () => _answers[index] = value!,
                                                ),
                                                title: Text(option.$2),
                                              ),
                                            ),
                                            if (_answers.containsKey(index))
                                              Text(
                                                _answers[index] == question.correctIndex
                                                    ? 'Correct! ${question.explanation}'
                                                    : 'Keep trying. ${question.explanation}',
                                                style: TextStyle(
                                                  color:
                                                      _answers[index] == question.correctIndex
                                                      ? Colors.green
                                                      : Theme.of(context).colorScheme.error,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                          ],
                  const SizedBox(height: 14),
                  Row(
                                    );
                                  },
                                ),
                                _PairsView(
                                  title: 'Find each memory pair',
                                  pairs: content.memoryGame,
                                ),
                                _PairsView(
                                  title: 'Match each item',
                                  pairs: content.matchingActivity,
                                ),
                                ListView(
                                  children: [
                                    Text(
                                      'Daily Practice',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 10),
                                    Card(
                                      color: const Color(0xFFF4F8FF),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: const CircleAvatar(
                                          child: Icon(Icons.calendar_today_rounded),
                                        ),
                                        title: Text(content.dailyActivity),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      'Parent Tips',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    ...content.parentTips.map(
                                      (tip) => Card(
                                        color: const Color(0xFFFFFBED),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            child: Icon(Icons.lightbulb_rounded),
                      ),
                                          title: Text(tip),
                                          trailing: IconButton(
                                            onPressed: () => _tts.speak(tip),
                                            tooltip: 'Read tip aloud',
                                            icon: const Icon(Icons.volume_up_outlined),
                                          ),
                    ],
                  ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
                    ],
                  ),
                  const SizedBox(height: 14),
                  _QuickActions(
                    actions: [
                      _QuickActionCard(
                        icon: Icons.smart_display_rounded,
                        label: 'Flashcards',
                        color: const Color(0xFFE5F1F7),
                        onTap: () => context.go('/learn'),
                      ),
                      _QuickActionCard(
                        icon: Icons.sports_esports_rounded,
                        label: 'Games',
                        color: const Color(0xFFFFF0DD),
                        onTap: () => context.go('/learn'),
                      ),
                      _QuickActionCard(
                        icon: Icons.menu_book_rounded,
                        label: 'Stories',
                        color: const Color(0xFFE7F5E7),
                        onTap: () => context.go('/learn'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent Lessons',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/learn'),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  if (lessons.isEmpty)
                    const Text(
                      'Activities will appear here after you create a lesson.',
                    )
                  else
                    ...lessons.take(2).indexed.expand((entry) {
                      final lesson = entry.$2;
                      return [
                        _ActivityTile(
                          index: entry.$1 + 1,
                          title: lesson.content.title,
                          subtitle:
                              '${lesson.request.difficulty.name} • ${lesson.request.durationMinutes} min',
                          buttonLabel: 'Start',
                          color: entry.$1.isEven
                              ? const Color(0xFFE9F5E0)
                              : const Color(0xFFEFECFA),
                          onTap: () => context.push(
                            '/lesson/${lesson.id}',
                            extra: lesson,
                          ),
                        ),
                        if (entry.$1 == 0 && lessons.length > 1)
                          const SizedBox(height: 10),
                      ];
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  */
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.userName,
    required this.child,
    required this.children,
  });
  final String userName;
  final ChildProfile child;
  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF5F0FF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IKeriKin',
                      style: TextStyle(
                        color: Color(0xFF6738D1),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'I Care for Your Kin',
                      style: TextStyle(
                        color: Color(0xFFE83E82),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Good morning, ${userName.isEmpty ? 'Caregiver' : userName}!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Let's make today a great learning day with ${child.name}.",
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ChildAvatar(
                name: child.name,
                photoUrl: child.photoUrl,
                radius: 34,
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: child.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Learning profile',
              prefixIcon: Icon(Icons.child_care_rounded),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            items: children
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (id) =>
                ref.read(selectedChildProvider.notifier).select(id),
          ),
        ],
      ),
    ),
  );
}

/// Searchable lesson library derived from the active child's persisted lessons.
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key});

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final _searchController = TextEditingController();
  String _category = 'All';

  static const _categories = <_LessonCategory>[
    _LessonCategory(
      name: 'Life Skills',
      color: Color(0xFFD9EFF4),
      icon: Icons.clean_hands_rounded,
    ),
    _LessonCategory(
      name: 'Communication',
      color: Color(0xFFE8F2FA),
      icon: Icons.record_voice_over_rounded,
    ),
    _LessonCategory(
      name: 'Emotions',
      color: Color(0xFFFDE7D2),
      icon: Icons.mood_rounded,
    ),
    _LessonCategory(
      name: 'Academics',
      color: Color(0xFFF5E9CC),
      icon: Icons.abc_rounded,
    ),
    _LessonCategory(
      name: 'Cognitive Skills',
      color: Color(0xFFF5E6F2),
      icon: Icons.extension_rounded,
    ),
    _LessonCategory(
      name: 'Music & Audio',
      color: Color(0xFFE5F0FC),
      icon: Icons.music_note_rounded,
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Lesson> _filter(List<Lesson> lessons) {
    final query = _searchController.text.trim().toLowerCase();
    return lessons.where((lesson) {
      final matchesCategory =
          _category == 'All' || _categoryFor(lesson) == _category;
      final matchesSearch =
          query.isEmpty ||
          lesson.content.title.toLowerCase().contains(query) ||
          lesson.content.summary.toLowerCase().contains(query) ||
          lesson.request.goal.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  String _categoryFor(Lesson lesson) {
    final text =
        '${lesson.request.goal} ${lesson.content.title} '
                '${lesson.content.summary}'
            .toLowerCase();
    if (_containsAny(text, const [
      'speak',
      'speech',
      'communicat',
      'conversation',
      'word',
      'listen',
    ])) {
      return 'Communication';
    }
    if (_containsAny(text, const [
      'emotion',
      'feeling',
      'calm',
      'social',
      'friend',
      'behavior',
    ])) {
      return 'Emotions';
    }
    if (_containsAny(text, const [
      'read',
      'write',
      'math',
      'number',
      'letter',
      'science',
      'school',
    ])) {
      return 'Academics';
    }
    if (_containsAny(text, const [
      'memory',
      'focus',
      'concentrat',
      'pattern',
      'match',
      'problem',
    ])) {
      return 'Cognitive Skills';
    }
    if (_containsAny(text, const [
      'music',
      'song',
      'sing',
      'sound',
      'audio',
      'rhythm',
    ])) {
      return 'Music & Audio';
    }
    return 'Life Skills';
  }

  bool _containsAny(String text, List<String> terms) =>
      terms.any(text.contains);

  @override
  Widget build(BuildContext context) {
    final child = activeChild(ref);
    final lessonsState = child == null
        ? null
        : ref.watch(lessonsProvider(child.id));
    final lessons = lessonsState?.value ?? const <Lesson>[];
    final filteredLessons = _filter(lessons);
    final chips = ['All', ..._categories.map((category) => category.name)];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        actions: [
          IconButton(
            onPressed: () => context.push('/create'),
            tooltip: 'Create a lesson',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: ResponsiveBody(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: child == null
            ? EmptyState(
                icon: Icons.child_care_rounded,
                title: 'Choose a learning profile',
                message:
                    'Create or select a child profile before browsing lessons.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/children'),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Manage profiles'),
                ),
              )
            : ListView(
                children: [
                  Text(
                    'What does ${child.name} want to learn?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Search the lessons you have created or choose a skill area.',
                  ),
                  const SizedBox(height: 12),
                  SearchBar(
                    controller: _searchController,
                    hintText: 'Search by title or learning goal',
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: chips
                          .map(
                            (chip) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(chip),
                                selected: chip == _category,
                                onSelected: (_) =>
                                    setState(() => _category = chip),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 900
                        ? 3
                        : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .88,
                    children: _categories.map((category) {
                      final count = lessons
                          .where(
                            (lesson) => _categoryFor(lesson) == category.name,
                          )
                          .length;
                      return _CategoryCard(
                        title: category.name,
                        lessonCount: count,
                        color: category.color,
                        icon: category.icon,
                        selected: _category == category.name,
                        onTap: () => setState(() => _category = category.name),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _category == 'All' ? 'All lessons' : _category,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text('${filteredLessons.length} found'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (lessonsState?.isLoading ?? false)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (lessonsState?.hasError ?? false)
                    ErrorView(
                      message: lessonsState!.error.toString(),
                      onRetry: () => ref.invalidate(lessonsProvider(child.id)),
                    )
                  else if (filteredLessons.isEmpty)
                    EmptyState(
                      icon: lessons.isEmpty
                          ? Icons.auto_awesome_rounded
                          : Icons.search_off_rounded,
                      title: lessons.isEmpty
                          ? 'No lessons yet'
                          : 'No matching lessons',
                      message: lessons.isEmpty
                          ? 'Create the first personalized lesson for ${child.name}.'
                          : 'Try a different search or skill area.',
                      action: lessons.isEmpty
                          ? FilledButton.icon(
                              onPressed: () => context.push('/create'),
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Create lesson'),
                            )
                          : TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _category = 'All');
                              },
                              child: const Text('Clear filters'),
                            ),
                    )
                  else
                    ...filteredLessons.map(
                      (lesson) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          leading: CircleAvatar(
                            child: Icon(
                              _categories
                                  .firstWhere(
                                    (category) =>
                                        category.name == _categoryFor(lesson),
                                  )
                                  .icon,
                            ),
                          ),
                          title: Text(
                            lesson.content.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${_categoryFor(lesson)} • ${lesson.request.difficulty.name} • '
                            '${lesson.request.durationMinutes} min\n${lesson.content.summary}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.play_circle_fill_rounded),
                          onTap: () => context.push(
                            '/lesson/${lesson.id}',
                            extra: lesson,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _LessonHeroTile extends StatelessWidget {
  const _LessonHeroTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFF1EAFF),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 110,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFDCCFFF), Color(0xFFBDA6FF)],
                ),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                size: 44,
                color: Color(0xFF6738D1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(subtitle),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.color,
    required this.onTap,
  });
  final int index;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(child: Text('$index')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onTap, child: Text(buttonLabel)),
        ],
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.lessonCount,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final int lessonCount;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: selected ? Theme.of(context).colorScheme.primaryContainer : color,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Icon(icon, size: 28),
                ),
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text('$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'}'),
          ],
        ),
      ),
    ),
  );
}

/// Visual metadata for a lesson skill area.
class _LessonCategory {
  const _LessonCategory({
    required this.name,
    required this.color,
    required this.icon,
  });

  final String name;
  final Color color;
  final IconData icon;
}

/// Form that turns a learning goal into a structured AI request.
class LessonGeneratorScreen extends ConsumerStatefulWidget {
  const LessonGeneratorScreen({super.key});
  @override
  ConsumerState<LessonGeneratorScreen> createState() =>
      _LessonGeneratorScreenState();
}

class _LessonGeneratorScreenState extends ConsumerState<LessonGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _goal = TextEditingController();
  final _notes = TextEditingController();
  LessonDifficulty _difficulty = LessonDifficulty.easy;
  String _language = 'English';
  String _category = 'Daily Living Skills';
  double _duration = 15;
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    _goal.dispose();
    _notes.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    if (await _speech.initialize()) {
      setState(() => _listening = true);
      await _speech.listen(
        onResult: (result) {
          _goal.text = result.recognizedWords;
          if (result.finalResult && mounted) setState(() => _listening = false);
        },
      );
    } else if (mounted) {
      showMessage(
        context,
        'Speech recognition is not available on this device.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = activeChild(ref);
    final busy = ref.watch(lessonControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Create AI Lesson'),
            Text(
              'Tell us what you want your child to learn.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: ResponsiveBody(
        maxWidth: 760,
        child: child == null
            ? EmptyState(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Choose a child first',
                message:
                    'A child profile is required to personalize the lesson.',
                action: FilledButton(
                  onPressed: () => context.go('/children'),
                  child: const Text('View child profiles'),
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _StepPanel(
                      number: 1,
                      title: 'Select Child',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ChildAvatar(
                          name: child.name,
                          photoUrl: child.photoUrl,
                        ),
                        title: Text(
                          child.name,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text('Age ${child.age} • ${child.gender}'),
                        trailing: const Icon(Icons.expand_more_rounded),
                        onTap: () => context.push('/children'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StepPanel(
                      number: 2,
                      title: 'Lesson Details',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _goal,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Learning goal',
                              hintText: 'Example: Brushing my teeth',
                              suffixIcon: IconButton(
                                onPressed: _listen,
                                tooltip: 'Speak lesson goal',
                                icon: Icon(
                                  _listening
                                      ? Icons.stop_circle_rounded
                                      : Icons.mic_rounded,
                                ),
                              ),
                            ),
                            validator: (value) =>
                                (value?.trim().length ?? 0) >= 5
                                ? null
                                : 'Describe a clear learning goal',
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Lesson category',
                              prefixIcon: Icon(Icons.menu_book_outlined),
                            ),
                            items:
                                const [
                                      'Daily Living Skills',
                                      'Communication',
                                      'Emotions',
                                      'Academics',
                                      'Social Skills',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) =>
                                setState(() => _category = value!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Difficulty',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<LessonDifficulty>(
                      segments: const [
                        ButtonSegment(
                          value: LessonDifficulty.easy,
                          label: Text('Easy'),
                          icon: Icon(Icons.sentiment_satisfied_rounded),
                        ),
                        ButtonSegment(
                          value: LessonDifficulty.medium,
                          label: Text('Medium'),
                          icon: Icon(Icons.trending_up_rounded),
                        ),
                        ButtonSegment(
                          value: LessonDifficulty.challenging,
                          label: Text('Challenge'),
                          icon: Icon(Icons.rocket_launch_rounded),
                        ),
                      ],
                      selected: {_difficulty},
                      onSelectionChanged: (value) =>
                          setState(() => _difficulty = value.first),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(
                        labelText: 'Lesson language',
                        prefixIcon: Icon(Icons.translate_rounded),
                      ),
                      items: ProfileOptions.languages
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _language = value!),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Duration: ${_duration.round()} minutes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5 min')),
                        ButtonSegment(value: 10, label: Text('10 min')),
                        ButtonSegment(value: 15, label: Text('15 min')),
                      ],
                      selected: {_duration},
                      onSelectionChanged: (value) =>
                          setState(() => _duration = value.first),
                    ),
                    const SizedBox(height: 14),
                    _StepPanel(
                      number: 3,
                      title: 'Additional Information',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...child.disabilities.map(
                                (item) => Chip(label: Text(item)),
                              ),
                              ...child.interests
                                  .take(3)
                                  .map((item) => Chip(label: Text(item))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notes,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Additional notes (optional)',
                              hintText:
                                  'Sensory preferences, favorite character, or skills to avoid...',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Icon(Icons.auto_awesome_rounded),
                            ),
                            title: Text(
                              'What happens next?',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              'AI creates a story, flashcards, quiz, activities, and parent tips.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final request = LessonRequest(
                                id: const Uuid().v4(),
                                childId: child.id,
                                goal: _goal.text.trim(),
                                difficulty: _difficulty,
                                language: _language,
                                durationMinutes: _duration.round(),
                                additionalNotes: _notes.text.trim(),
                                createdAt: DateTime.now(),
                              );
                              try {
                                final lesson = await ref
                                    .read(lessonControllerProvider.notifier)
                                    .generate(request, child);
                                if (context.mounted)
                                  context.push(
                                    '/lesson/${lesson.id}',
                                    extra: lesson,
                                  );
                              } catch (error) {
                                if (context.mounted)
                                  showMessage(
                                    context,
                                    error.toString(),
                                    error: true,
                                  );
                              }
                            },
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        busy
                            ? 'Creating personalized lesson…'
                            : 'Generate AI Lesson',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _StepPanel extends StatelessWidget {
  const _StepPanel({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 15, child: Text('$number')),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF6738D1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

/// Resolves persisted lesson data for direct links and browser refreshes.
class LessonRouteScreen extends ConsumerWidget {
  const LessonRouteScreen({
    super.key,
    required this.lessonId,
    this.initialLesson,
  });

  final String lessonId;
  final Lesson? initialLesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = initialLesson;
    if (lesson != null) return LessonDetailScreen(lesson: lesson);

    final child = activeChild(ref);
    if (child == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Lesson unavailable',
          message: 'Select a child profile to open this lesson.',
        ),
      );
    }

    return ref
        .watch(lessonsProvider(child.id))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) =>
              Scaffold(body: ErrorView(message: error.toString())),
          data: (lessons) {
            final resolved = lessons
                .where((item) => item.id == lessonId)
                .firstOrNull;
            if (resolved == null) {
              return const Scaffold(
                body: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Lesson not found',
                  message: 'This lesson may have been removed.',
                ),
              );
            }
            return LessonDetailScreen(lesson: resolved);
          },
        );
  }
}

/// Interactive renderer for all structured lesson content types.
class LessonDetailScreen extends ConsumerStatefulWidget {
  const LessonDetailScreen({super.key, required this.lesson});
  final Lesson lesson;
  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);
  final FlutterTts _tts = FlutterTts();
  final Map<int, int> _answers = {};
  int _minutes = 0;
  late final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void dispose() {
    _tabs.dispose();
    _tts.stop();
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _finish() async {
    _minutes = (_stopwatch.elapsed.inSeconds / 60).ceil().clamp(1, 180);
    final quiz = widget.lesson.content.quiz;
    final correct = quiz.indexed
        .where((entry) => _answers[entry.$1] == entry.$2.correctIndex)
        .length;
    final score = quiz.isEmpty ? 100 : ((correct / quiz.length) * 100).round();
    await ref
        .read(lessonControllerProvider.notifier)
        .complete(widget.lesson, score, _minutes);
    if (mounted)
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, size: 54),
          title: const Text('Lesson complete!'),
          content: Text('Quiz score: $score%\nYou earned 100 XP and 20 coins.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/home');
              },
              child: const Text('Great!'),
            ),
          ],
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.lesson.content;
    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Story'),
            Tab(text: 'Video'),
            Tab(text: 'Cards'),
            Tab(text: 'Quiz'),
            Tab(text: 'Memory'),
            Tab(text: 'Match'),
            Tab(text: 'For Parents'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _finish,
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text('Finish'),
      ),
      body: ResponsiveBody(
        maxWidth: 900,
        child: TabBarView(
          controller: _tabs,
          children: [
            ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        content.summary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _tts.speak(content.story),
                      tooltip: 'Read story aloud',
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      content.story,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(height: 1.7),
                    ),
                  ),
                ),
              ],
            ),
            _LessonVideoView(lesson: widget.lesson),
            ListView.separated(
              itemCount: content.flashcards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, index) =>
                  _FlipCard(card: content.flashcards[index]),
            ),
            ListView.builder(
              itemCount: content.quiz.length,
              itemBuilder: (context, index) {
                final question = content.quiz[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}. ${question.question}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        ...question.options.indexed.map(
                          (option) => RadioListTile<int>(
                            value: option.$1,
                            groupValue: _answers[index],
                            onChanged: (value) =>
                                setState(() => _answers[index] = value!),
                            title: Text(option.$2),
                          ),
                        ),
                        if (_answers.containsKey(index))
                          Text(
                            _answers[index] == question.correctIndex
                                ? 'Correct! ${question.explanation}'
                                : 'Keep trying. ${question.explanation}',
                            style: TextStyle(
                              color: _answers[index] == question.correctIndex
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            _PairsView(
              title: 'Find each memory pair',
              pairs: content.memoryGame,
            ),
            _PairsView(
              title: 'Match each item',
              pairs: content.matchingActivity,
            ),
            ListView(
              children: [
                Text(
                  'Daily activity',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(content.dailyActivity),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Parent tips',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ...content.parentTips.map(
                  (tip) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.lightbulb_rounded),
                      ),
                      title: Text(tip),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonVideoView extends ConsumerStatefulWidget {
  const _LessonVideoView({required this.lesson});

  final Lesson lesson;

  @override
  ConsumerState<_LessonVideoView> createState() => _LessonVideoViewState();
}

class _LessonVideoViewState extends ConsumerState<_LessonVideoView> {
  VideoGeneration? _generation;
  VideoPlayerController? _player;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final provider = ref.read(aiVideoProvider);
    if (provider == null) {
      setState(() => _error = 'Connect Supabase to generate AI videos.');
      return;
    }

    await _player?.dispose();
    setState(() {
      _player = null;
      _generation = null;
      _error = null;
      _busy = true;
    });

    try {
      var generation = await provider.create(widget.lesson);
      if (!mounted) return;
      setState(() => _generation = generation);

      while (mounted && !generation.isComplete && !generation.isFailed) {
        await Future<void>.delayed(const Duration(seconds: 10));
        if (!mounted) return;
        generation = await provider.getStatus(generation.id);
        setState(() => _generation = generation);
      }

      if (!mounted) return;
      if (generation.isFailed) {
        throw Exception(generation.error ?? 'The video render failed.');
      }

      final player = VideoPlayerController.networkUrl(
        provider.contentUri(generation.id),
        httpHeaders: provider.contentHeaders,
      );
      await player.initialize();
      if (!mounted) {
        await player.dispose();
        return;
      }
      await player.play();
      setState(() => _player = player);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final generation = _generation;
    return ListView(
      children: [
        if (player != null && player.value.isInitialized) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
          ),
          VideoProgressIndicator(player, allowScrubbing: true),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => setState(() {
                  player.value.isPlaying ? player.pause() : player.play();
                }),
                tooltip: player.value.isPlaying ? 'Pause video' : 'Play video',
                icon: Icon(
                  player.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _generate,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try another'),
              ),
            ],
          ),
        ] else ...[
          Container(
            constraints: const BoxConstraints(minHeight: 240),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: _busy
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: (generation?.progress ?? 0) > 0
                              ? generation!.progress / 100
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          generation?.status == 'in_progress'
                              ? 'Rendering video ${generation!.progress}%'
                              : 'Preparing video render',
                        ),
                      ],
                    )
                  : const Icon(Icons.movie_creation_outlined, size: 64),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _generate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate AI Video'),
          ),
        ],
      ],
    );
  }
}

class _FlipCard extends StatefulWidget {
  const _FlipCard({required this.card});
  final Flashcard card;
  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> {
  bool flipped = false;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => setState(() => flipped = !flipped),
    borderRadius: BorderRadius.circular(24),
    child: Card(
      child: SizedBox(
        height: 180,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  flipped ? widget.card.back : widget.card.front,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(flipped ? 'Tap to see question' : 'Tap to reveal answer'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PairsView extends StatelessWidget {
  const _PairsView({required this.title, required this.pairs});
  final String title;
  final List<ActivityPair> pairs;
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 14),
      ...pairs.map(
        (pair) => Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pair.left,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.sync_alt_rounded),
                Expanded(
                  child: Text(
                    pair.right,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
