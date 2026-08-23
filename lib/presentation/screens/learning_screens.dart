import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/decorative_scenes.dart';

/// Resolves the active child from the authenticated parent's profiles.
ChildProfile? activeChild(WidgetRef ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final children = ref.watch(childrenProvider(user.id)).value ?? [];
  final selectedId = ref.watch(selectedChildProvider);
  return children.where((child) => child.id == selectedId).firstOrNull ??
      children.firstOrNull;
}

/// A time-of-day greeting shared by every screen that opens with one.
String timeOfDayGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

/// Opens a bottom sheet listing every child profile so a caregiver can
/// switch which learner the rest of the app is personalized around.
Future<void> pickChildSheet(
  BuildContext context,
  WidgetRef ref, {
  required String currentChildId,
  required List<ChildProfile> children,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch learner',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final item in children)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ChildAvatar(
                  name: item.name,
                  photoUrl: item.photoUrl,
                  gender: item.gender,
                  radius: 20,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: item.id == currentChildId
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.brandViolet,
                      )
                    : null,
                onTap: () {
                  ref.read(selectedChildProvider.notifier).select(item.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// Personalized parent dashboard and child learning launchpad, styled after
/// IKeriKin's "calm story path" concept: a gradient brand masthead, a
/// learner panel, a horizontal daily-activity path, and a lesson shelf.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _dailyTarget = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const LoadingView(message: 'Signing you in…');
    final childrenState = ref.watch(childrenProvider(user.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SceneBackground(
        scene: SceneKind.home,
        child: ResponsiveBody(
          maxWidth: 1600,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: childrenState.when(
            loading: () => const LoadingView(message: 'Loading your family…'),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(childrenProvider(user.id)),
            ),
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
              final completedToday = progress.completedToday.clamp(
                0,
                _dailyTarget,
              );
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(lessonsProvider(child.id));
                  ref.invalidate(progressProvider(child.id));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const AnimatedAppear(child: _Masthead()),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final left = [
                          AnimatedAppear(
                            delay: staggerDelay(1),
                            child: _LearnerPanel(
                              userName: user.displayName,
                              child: child,
                              children: children,
                            ),
                          ),
                          const SizedBox(height: 18),
                          AnimatedAppear(
                            delay: staggerDelay(2),
                            child: _LearningPathCard(
                              childName: child.name,
                              completed: completedToday,
                              target: _dailyTarget,
                            ),
                          ),
                        ];
                        final right = [
                          AnimatedAppear(
                            delay: staggerDelay(3),
                            child: _NextStationCard(
                              childName: child.name,
                              nextLesson: lessons.firstOrNull,
                              onCreate: () => context.go('/create'),
                              onContinue: (lesson) => context.push(
                                '/lesson/${lesson.id}',
                                extra: lesson,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          AnimatedAppear(
                            delay: staggerDelay(4),
                            child: _LessonShelfSection(
                              childName: child.name,
                              lessons: lessons,
                              onSeeAll: () => context.go('/learn'),
                              onOpen: (lesson) => context.push(
                                '/lesson/${lesson.id}',
                                extra: lesson,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          AnimatedAppear(
                            delay: staggerDelay(5),
                            child: _ProgressSummaryLine(
                              progress: progress,
                              onViewProgress: () => context.go('/progress'),
                            ),
                          ),
                        ];
                        if (constraints.maxWidth < 760) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...left,
                              const SizedBox(height: 22),
                              ...right,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 35,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: left,
                              ),
                            ),
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 65,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: right,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Brand gradient masthead: colorful wordmark, tagline, and a settings
/// shortcut, echoing IKeriKin's calm-story-path home concept art.
class _Masthead extends StatelessWidget {
  const _Masthead();

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: AppTheme.heroGradient(context),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandViolet.withValues(alpha: .24),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BubbleWordmark(fontSize: 28),
                const SizedBox(height: 6),
                Text(
                  'I Care for Your Kin',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .9),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_greeting()} · a quiet start for today',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .78),
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings and accessibility',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .18),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

/// White "learner panel" naming who the household is currently learning
/// with, plus a modal picker for switching between children.
class _LearnerPanel extends ConsumerWidget {
  const _LearnerPanel({
    required this.userName,
    required this.child,
    required this.children,
  });
  final String userName;
  final ChildProfile child;
  final List<ChildProfile> children;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _pickChild(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Switch learner',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final item in children)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ChildAvatar(
                    name: item.name,
                    photoUrl: item.photoUrl,
                    gender: item.gender,
                    radius: 20,
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  trailing: item.id == child.id
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.brandViolet,
                        )
                      : null,
                  onTap: () {
                    ref.read(selectedChildProvider.notifier).select(item.id);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECTED LEARNER',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChildAvatar(
                name: child.name,
                photoUrl: child.photoUrl,
                gender: child.gender,
                radius: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greeting()}, ${userName.isEmpty ? 'Caregiver' : userName}!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Learning with ${child.name}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (children.length > 1) ...[
            const SizedBox(height: 16),
            Material(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                onTap: () => _pickChild(context, ref),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        color: AppTheme.brandViolet,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Switch learner',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal "learning path" of today's activities, echoing the connected
/// waypoints in IKeriKin's calm-story-path home concept.
class _LearningPathCard extends StatelessWidget {
  const _LearningPathCard({
    required this.childName,
    required this.completed,
    required this.target,
  });
  final String childName;
  final int completed;
  final int target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$childName’s learning path',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedCounter(
                    value: completed,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brandViolet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    ' / $target',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brandViolet,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Today: $completed of $target learning activities',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Semantics(
            label: '$completed of $target learning activities complete',
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < target; i++) ...[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 20),
                        color: i <= completed
                            ? AppTheme.brandViolet.withValues(alpha: .4)
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                  _PathStop(index: i + 1, done: i < completed),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Each stop lights up as an activity is completed today.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PathStop extends StatelessWidget {
  const _PathStop({required this.index, required this.done});
  final int index;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = prefersReducedMotion(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(done),
          tween: Tween(begin: done ? 0.7 : 1, end: 1),
          duration: reduced ? Duration.zero : const Duration(milliseconds: 360),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppTheme.brandViolet
                  : theme.colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: done
                    ? AppTheme.brandViolet
                    : theme.colorScheme.outlineVariant,
                width: 2,
              ),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: done ? Colors.white : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Activity',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The single next action a caregiver should take, echoing the "next
/// station" call-to-action card from the concept art.
class _NextStationCard extends StatelessWidget {
  const _NextStationCard({
    required this.childName,
    required this.nextLesson,
    required this.onCreate,
    required this.onContinue,
  });
  final String childName;
  final Lesson? nextLesson;
  final VoidCallback onCreate;
  final ValueChanged<Lesson> onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = nextLesson;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.brandViolet.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Icon(
                  lesson == null
                      ? Icons.auto_stories_rounded
                      : Icons.play_circle_rounded,
                  color: AppTheme.brandViolet,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson == null ? 'NEXT STATION' : 'CONTINUE LEARNING',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandViolet,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lesson == null
                          ? 'Create $childName’s first lesson'
                          : lesson.content.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            lesson == null
                ? 'Choose one learning goal. IKeriKin builds a story, cards, a quiz, activities, and parent tips around it.'
                : lesson.content.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: BouncyTap(
              scale: .97,
              child: FilledButton.icon(
                onPressed: lesson == null ? onCreate : () => onContinue(lesson),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandViolet,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: Icon(
                  lesson == null ? Icons.add_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(
                  lesson == null ? 'Choose a learning goal' : 'Continue lesson',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Lesson shelf": the running list of everything IKeriKin has generated
/// for this child, or a friendly empty state before the first one exists.
class _LessonShelfSection extends StatelessWidget {
  const _LessonShelfSection({
    required this.childName,
    required this.lessons,
    required this.onSeeAll,
    required this.onOpen,
  });
  final String childName;
  final List<Lesson> lessons;
  final VoidCallback onSeeAll;
  final ValueChanged<Lesson> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lessons.isEmpty
                        ? 'NO LESSONS YET'
                        : '${lessons.length} SAVED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your lesson shelf',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (lessons.isNotEmpty)
              TextButton.icon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'See all',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const Divider(height: 24),
        if (lessons.isEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nothing to open yet',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Choose a learning goal to add $childName’s first lesson here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              for (final (index, lesson) in lessons.take(3).indexed) ...[
                if (index > 0) const SizedBox(height: 10),
                _ActivityTile(
                  index: index + 1,
                  title: lesson.content.title,
                  subtitle:
                      '${lesson.request.difficulty.name} • ${lesson.request.durationMinutes} min',
                  buttonLabel: 'Open',
                  onTap: () => onOpen(lesson),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// One-line progress recap that links out to the full Progress tab, instead
/// of duplicating its stat cards on the home screen.
class _ProgressSummaryLine extends StatelessWidget {
  const _ProgressSummaryLine({
    required this.progress,
    required this.onViewProgress,
  });
  final ProgressSummary progress;
  final VoidCallback onViewProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final started =
        progress.xp > 0 ||
        progress.coins > 0 ||
        progress.streakDays > 0 ||
        progress.badges.isNotEmpty;
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress so far',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  started
                      ? '${progress.xp} XP · ${progress.coins} coins · ${progress.streakDays}-day streak · ${progress.badges.length} badges'
                      : 'XP, coins, streaks, and badges will appear as your child learns.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onViewProgress,
            child: const Text(
              'View progress',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
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
    final user = ref.watch(authStateProvider).value;
    final child = activeChild(ref);
    final children = user == null
        ? const <ChildProfile>[]
        : ref.watch(childrenProvider(user.id)).value ?? const <ChildProfile>[];
    final lessonsState = child == null
        ? null
        : ref.watch(lessonsProvider(child.id));
    final lessons = lessonsState?.value ?? const <Lesson>[];
    final filteredLessons = _filter(lessons);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SceneBackground(
        scene: SceneKind.learn,
        child: ResponsiveBody(
          maxWidth: 1600,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: RefreshIndicator(
            onRefresh: () async {
              if (child != null) ref.invalidate(lessonsProvider(child.id));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                HeroBanner(
                  icon: Icons.menu_book_rounded,
                  title: 'Learn',
                  colorfulTitle: true,
                  subtitle: child == null
                      ? 'Choose a learning profile to browse lessons.'
                      : 'Find a lesson by skill, title, or learning goal.',
                  actions: [
                    MastheadAction(
                      icon: Icons.menu_book_outlined,
                      tooltip: 'Word Explorer',
                      onPressed: () => context.push('/dictionary'),
                    ),
                    MastheadAction(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings and accessibility',
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (child == null)
                  EmptyState(
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
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final learnerColumn = _LearnerColumn(
                        userName: user?.displayName ?? '',
                        child: child,
                        children: children,
                      );
                      final libraryColumn = _LibraryColumn(
                        child: child,
                        searchController: _searchController,
                        onSearchChanged: () => setState(() {}),
                        categories: _categories,
                        lessons: lessons,
                        categoryOf: _categoryFor,
                        selectedCategory: _category,
                        onCategorySelected: (value) =>
                            setState(() => _category = value),
                        filteredLessons: filteredLessons,
                        loading: lessonsState?.isLoading ?? false,
                        error: lessonsState?.hasError ?? false
                            ? lessonsState!.error.toString()
                            : null,
                        onRetry: () =>
                            ref.invalidate(lessonsProvider(child.id)),
                        onClearFilters: () {
                          _searchController.clear();
                          setState(() => _category = 'All');
                        },
                      );
                      if (constraints.maxWidth < 760) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            learnerColumn,
                            const SizedBox(height: 26),
                            libraryColumn,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 250, child: learnerColumn),
                          const SizedBox(width: 36),
                          Expanded(child: libraryColumn),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Selected learner" rail: who the library is being browsed for, and a
/// way to switch, echoing the Kombai "Calm Story Shelf" learn concept.
class _LearnerColumn extends ConsumerWidget {
  const _LearnerColumn({
    required this.userName,
    required this.child,
    required this.children,
  });
  final String userName;
  final ChildProfile child;
  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECTED LEARNER',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Learning with ${child.name}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${timeOfDayGreeting()}, ${userName.isEmpty ? 'Caregiver' : userName}. Choose a gentle next step together.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChildAvatar(
                    name: child.name,
                    photoUrl: child.photoUrl,
                    gender: child.gender,
                    radius: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Age ${child.age} · ${child.preferredLanguage}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (children.length > 1) ...[
                const SizedBox(height: 16),
                Material(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    onTap: () => pickChildSheet(
                      context,
                      ref,
                      currentChildId: child.id,
                      children: children,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Switch learner',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: 'One clear place to begin.\n',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text:
                      'Browse lessons already made for ${child.name}, or create a new one around a goal.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Search, skill index, and lesson shelf for the active child, echoing the
/// Kombai "Calm Story Shelf" learn concept.
class _LibraryColumn extends StatelessWidget {
  const _LibraryColumn({
    required this.child,
    required this.searchController,
    required this.onSearchChanged,
    required this.categories,
    required this.lessons,
    required this.categoryOf,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.filteredLessons,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onClearFilters,
  });

  final ChildProfile child;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<_LessonCategory> categories;
  final List<Lesson> lessons;
  final String Function(Lesson) categoryOf;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final List<Lesson> filteredLessons;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LESSON LIBRARY',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose what ${child.name} will practice next.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/create'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create a lesson',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SearchBar(
          controller: searchController,
          hintText: 'Search by title or learning goal',
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (searchController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  searchController.clear();
                  onSearchChanged();
                },
                tooltip: 'Clear search',
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          onChanged: (_) => onSearchChanged(),
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Skill index',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${categories.length} learning areas',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 3 : 2;
            final items = [
              (index: 1, name: 'All', count: lessons.length),
              for (final (i, category) in categories.indexed)
                (
                  index: i + 2,
                  name: category.name,
                  count: lessons
                      .where((lesson) => categoryOf(lesson) == category.name)
                      .length,
                ),
            ];
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.2,
              children: [
                for (final item in items)
                  AnimatedAppear(
                    delay: staggerDelay(item.index),
                    child: _SkillIndexItem(
                      index: item.index,
                      name: item.name,
                      count: item.count,
                      selected: item.name == selectedCategory,
                      onTap: () => onCategorySelected(item.name),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Lessons for ${child.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${filteredLessons.length} ${filteredLessons.length == 1 ? 'lesson' : 'lessons'} found',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Divider(height: 20),
        if (loading)
          const LoadingView(message: 'Loading lessons…')
        else if (error != null)
          ErrorView(message: error!, onRetry: onRetry)
        else if (filteredLessons.isEmpty)
          EmptyState(
            icon: lessons.isEmpty
                ? Icons.auto_awesome_rounded
                : Icons.search_off_rounded,
            title: lessons.isEmpty ? 'No lessons yet' : 'No matching lessons',
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
                    onPressed: onClearFilters,
                    child: const Text('Clear filters'),
                  ),
          )
        else
          for (final (index, lesson) in filteredLessons.indexed) ...[
            if (index > 0) const Divider(height: 1),
            AnimatedAppear(
              delay: staggerDelay(index),
              child: _LessonShelfRow(
                index: index + 1,
                featured: index == 0,
                title: lesson.content.title,
                summary: lesson.content.summary,
                category: categoryOf(lesson),
                difficulty: lesson.request.difficulty.name,
                durationMinutes: lesson.request.durationMinutes,
                goal: lesson.request.goal,
                onTap: () =>
                    context.push('/lesson/${lesson.id}', extra: lesson),
              ),
            ),
          ],
      ],
    );
  }
}

/// One numbered row in the "skill index" grid used to filter the lesson
/// shelf by category.
class _SkillIndexItem extends StatelessWidget {
  const _SkillIndexItem({
    required this.index,
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BouncyTap(
      onTap: onTap,
      scale: .97,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.brandViolet.withValues(alpha: .1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppTheme.brandViolet
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Text(
              index.toString().padLeft(2, '0'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected
                    ? AppTheme.brandViolet
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: selected ? AppTheme.brandViolet : null,
                ),
              ),
            ),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One numbered row in the lesson shelf, with the first (most recent)
/// lesson highlighted as "featured".
class _LessonShelfRow extends StatelessWidget {
  const _LessonShelfRow({
    required this.index,
    required this.featured,
    required this.title,
    required this.summary,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.goal,
    required this.onTap,
  });
  final int index;
  final bool featured;
  final String title;
  final String summary;
  final String category;
  final String difficulty;
  final int durationMinutes;
  final String goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: featured ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: featured
                    ? AppTheme.brandViolet
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Text(
                      category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      difficulty,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$durationMinutes min',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (goal.isNotEmpty)
                      Text(
                        'Goal: $goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Open lesson',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (!featured) {
      return InkWell(onTap: onTap, child: content);
    }
    return HoverLift(
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: AppTheme.softShadow(context),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });
  final int index;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverLift(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: Text(
                    '$index',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  child: Text(buttonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  String _contentType = ProfileOptions.contentTypes.first;
  String _videoDurationLabel = ProfileOptions.videoDurations.keys.first;
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
    final user = ref.watch(authStateProvider).value;
    final child = activeChild(ref);
    final children = user == null
        ? const <ChildProfile>[]
        : ref.watch(childrenProvider(user.id)).value ?? const <ChildProfile>[];
    final busy = ref.watch(lessonControllerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SceneBackground(
        scene: SceneKind.create,
        child: ResponsiveBody(
          maxWidth: 1500,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ListView(
            children: [
              HeroBanner(
                icon: Icons.auto_awesome_rounded,
                title: 'Create a lesson',
                colorfulTitle: true,
                subtitle: child == null
                    ? 'Choose a child profile to personalize a new lesson.'
                    : 'Choose one goal; the rest of the lesson will follow.',
              ),
              const SizedBox(height: 18),
              if (child == null)
                EmptyState(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Choose a child first',
                  message:
                      'A child profile is required to personalize the lesson.',
                  action: FilledButton(
                    onPressed: () => context.go('/children'),
                    child: const Text('View child profiles'),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final formColumn = Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LearnerStrip(child: child, children: children),
                          const SizedBox(height: 20),
                          _StationPanel(
                            number: 1,
                            title: 'Choose a learning goal',
                            subtitle: 'Start with one clear, everyday skill.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _goal,
                                  minLines: 2,
                                  maxLines: 3,
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                const SizedBox(height: 8),
                                Text(
                                  'A specific goal helps the lesson meet ${child.name} at their pace.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _StationPanel(
                            number: 2,
                            title: 'Shape the lesson',
                            subtitle:
                                'Choose the format that feels right today.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const SizedBox(height: 18),
                                Text(
                                  'Difficulty',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<LessonDifficulty>(
                                  segments: const [
                                    ButtonSegment(
                                      value: LessonDifficulty.easy,
                                      label: Text('Easy'),
                                      icon: Icon(
                                        Icons.sentiment_satisfied_rounded,
                                      ),
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
                                const SizedBox(height: 18),
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
                                  onChanged: (value) =>
                                      setState(() => _language = value!),
                                ),
                                const SizedBox(height: 18),
                                DropdownButtonFormField<String>(
                                  initialValue: _contentType,
                                  decoration: const InputDecoration(
                                    labelText: 'Lesson content style',
                                    prefixIcon: Icon(
                                      Icons.movie_creation_outlined,
                                    ),
                                  ),
                                  items: ProfileOptions.contentTypes
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _contentType = value!),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Duration',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'How long the lesson and its video should be.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: ProfileOptions.videoDurations.keys
                                      .map((label) {
                                        return ChoiceChip(
                                          label: Text(label),
                                          selected:
                                              _videoDurationLabel == label,
                                          onSelected: (_) => setState(
                                            () => _videoDurationLabel = label,
                                          ),
                                        );
                                      })
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _StationPanel(
                            number: 3,
                            title: 'Add helpful context',
                            subtitle:
                                'Optional details keep the activity personal.',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (child.interests.isNotEmpty) ...[
                                  Text(
                                    '${child.name}’s interests',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: child.interests
                                        .map((item) => Chip(label: Text(item)))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (child.learningStyles.isNotEmpty) ...[
                                  Text(
                                    '${child.name}’s learning styles',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: child.learningStyles
                                        .map((item) => Chip(label: Text(item)))
                                        .toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Ready when you are.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Text(
                                        'You can adjust the lesson after it is created.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          BouncyTap(
                            scale: .97,
                            child: FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }
                                      final videoDurationSeconds =
                                          ProfileOptions
                                              .videoDurations[_videoDurationLabel] ??
                                          60;
                                      final request = LessonRequest(
                                        id: const Uuid().v4(),
                                        childId: child.id,
                                        goal: _goal.text.trim(),
                                        difficulty: _difficulty,
                                        language: _language,
                                        durationMinutes:
                                            videoDurationSeconds ~/ 60,
                                        additionalNotes: _notes.text.trim(),
                                        createdAt: DateTime.now(),
                                        contentType: _contentType,
                                        videoDurationSeconds:
                                            videoDurationSeconds,
                                      );
                                      try {
                                        final lesson = await ref
                                            .read(
                                              lessonControllerProvider.notifier,
                                            )
                                            .generate(request, child);
                                        if (context.mounted) {
                                          context.push(
                                            '/lesson/${lesson.id}',
                                            extra: lesson,
                                          );
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          showMessage(
                                            context,
                                            error.toString(),
                                            error: true,
                                          );
                                        }
                                      }
                                    },
                              icon: const GeminiSparkleIcon(),
                              label: Text(
                                busy
                                    ? 'Creating personalized lesson…'
                                    : 'Create personalized lesson',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                    final summaryColumn = _LessonBriefPanel(
                      childName: child.name,
                    );
                    if (constraints.maxWidth < 900) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          formColumn,
                          const SizedBox(height: 20),
                          summaryColumn,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 62, child: formColumn),
                        const SizedBox(width: 28),
                        Expanded(flex: 38, child: summaryColumn),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "learning with X" strip shown above the create-lesson stations,
/// with a way to switch which child the lesson is for.
class _LearnerStrip extends ConsumerWidget {
  const _LearnerStrip({required this.child, required this.children});
  final ChildProfile child;
  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          ChildAvatar(
            name: child.name,
            photoUrl: child.photoUrl,
            gender: child.gender,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(text: 'Learning with '),
                  TextSpan(
                    text: child.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: '\nAge ${child.age} · ${child.gender}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          if (children.length > 1)
            TextButton.icon(
              onPressed: () => pickChildSheet(
                context,
                ref,
                currentChildId: child.id,
                children: children,
              ),
              icon: const Icon(Icons.groups_rounded, size: 18),
              label: const Text(
                'Switch learner',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }
}

/// Numbered "station" card used to break the lesson-creation form into
/// three focused steps: goal, shape, and context.
class _StationPanel extends StatelessWidget {
  const _StationPanel({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final int number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.brandViolet.withValues(alpha: .14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AppTheme.brandViolet,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Static "what you'll receive" summary sidebar shown beside the
/// lesson-creation form on wide screens.
class _LessonBriefPanel extends StatelessWidget {
  const _LessonBriefPanel({required this.childName});
  final String childName;

  static const _features = [
    (
      icon: Icons.menu_book_rounded,
      title: 'Story',
      description: 'A familiar way into the idea.',
    ),
    (
      icon: Icons.style_rounded,
      title: 'Flashcards',
      description: 'Small prompts to revisit.',
    ),
    (
      icon: Icons.quiz_rounded,
      title: 'Quiz',
      description: 'A gentle check for understanding.',
    ),
    (
      icon: Icons.extension_rounded,
      title: 'Activities',
      description: 'Practice that fits the goal.',
    ),
    (
      icon: Icons.favorite_rounded,
      title: 'Parent tips',
      description: 'Ideas for learning together.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: AppTheme.softShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR LESSON BRIEF',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'What IKeriKin will make',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'One goal becomes a set of gentle ways for $childName to learn, practice, and try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              for (final feature in _features) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.brandViolet.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        feature.icon,
                        size: 18,
                        color: AppTheme.brandViolet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            feature.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 14),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text: 'No sparkle required. ',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text:
                          'The important part is the goal you choose and the way $childName learns best.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.brandViolet.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: AppTheme.brandViolet.withValues(alpha: .25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded, color: AppTheme.brandViolet),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Built around $childName\n',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'This lesson will use the selected profile, language, interests, and learning styles.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Lesson unavailable',
          message: 'Select a child profile to open this lesson.',
        ),
      );
    }

    return ref
        .watch(lessonsProvider(child.id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const LoadingView(message: 'Opening lesson…'),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: error.toString()),
          ),
          data: (lessons) {
            final resolved = lessons
                .where((item) => item.id == lessonId)
                .firstOrNull;
            if (resolved == null) {
              return Scaffold(
                appBar: AppBar(),
                body: const EmptyState(
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

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  bool _showVideo = false;
  final FlutterTts _tts = FlutterTts();
  final Map<int, int> _answers = {};
  int _minutes = 0;
  late final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(accessibilityProvider).textToSpeech) {
        _tts.speak(widget.lesson.content.story);
      }
    });
  }

  @override
  void dispose() {
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

  Widget _buildCardsSection(LessonContent content) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final card in content.flashcards) ...[
        _FlipCard(card: card),
        const SizedBox(height: 12),
      ],
    ],
  );

  Widget _buildQuizSection(BuildContext context, LessonContent content) {
    final answered = _answers.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Answered $answered of ${content.quiz.length}',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: content.quiz.isEmpty ? 1 : answered / content.quiz.length,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),
        for (final (index, question) in content.quiz.indexed) ...[
          Builder(
            builder: (context) {
              final answer = _answers[index];
              final correct = answer == question.correctIndex;
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
                          groupValue: answer,
                          onChanged: (value) =>
                              setState(() => _answers[index] = value!),
                          title: Text(option.$2),
                        ),
                      ),
                      if (answer != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: correct
                                ? Colors.green.withValues(alpha: .12)
                                : Theme.of(context).colorScheme.errorContainer,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                correct
                                    ? Icons.check_circle_rounded
                                    : Icons.refresh_rounded,
                                color: correct
                                    ? Colors.green.shade700
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  correct
                                      ? 'Correct! ${question.explanation}'
                                      : 'Keep trying. ${question.explanation}',
                                  style: TextStyle(
                                    color: correct
                                        ? Colors.green.shade900
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildParentsSection(BuildContext context, LessonContent content) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Daily activity',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 4, color: AppTheme.brandTeal),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(content.dailyActivity),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Parent tips',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...content.parentTips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.brandPink.withValues(alpha: .16),
                    foregroundColor: AppTheme.brandPink,
                    child: const Icon(Icons.lightbulb_rounded),
                  ),
                  title: Text(tip),
                ),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final content = widget.lesson.content;
    final child = activeChild(ref);
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.55).clamp(
      420.0,
      640.0,
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _finish,
        icon: const Icon(Icons.check_circle_rounded),
        label: const Text('Finish'),
      ),
      body: SceneBackground(
        scene: SceneKind.learn,
        child: ResponsiveBody(
          maxWidth: 1300,
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 96),
          child: ListView(
            children: [
              _LessonMetaHeader(
                content: content,
                request: widget.lesson.request,
              ),
              const SizedBox(height: 18),
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Story'),
                      icon: Icon(Icons.auto_stories_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Video'),
                      icon: Icon(Icons.smart_display_rounded),
                    ),
                  ],
                  selected: {_showVideo},
                  onSelectionChanged: (value) =>
                      setState(() => _showVideo = value.first),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: contentHeight,
                child: _showVideo
                    ? _AnimatedVideoView(lesson: widget.lesson, child: child)
                    : _StoryReadingSurface(
                        content: content,
                        onListen: () => _tts.speak(content.story),
                        onStartLearning: () =>
                            setState(() => _showVideo = true),
                      ),
              ),
              const SizedBox(height: 28),
              const SectionHeading(
                eyebrow: 'Practice & explore',
                title: 'More ways to learn',
              ),
              const SizedBox(height: 10),
              _PracticeSection(
                icon: Icons.style_rounded,
                color: AppTheme.brandCoral,
                title: 'Cards',
                child: _buildCardsSection(content),
              ),
              _PracticeSection(
                icon: Icons.quiz_rounded,
                color: AppTheme.brandViolet,
                title: 'Quiz',
                child: _buildQuizSection(context, content),
              ),
              _PracticeSection(
                icon: Icons.psychology_rounded,
                color: AppTheme.brandTeal,
                title: 'Memory',
                child: _PairsView(
                  title: 'Find each memory pair',
                  pairs: content.memoryGame,
                ),
              ),
              _PracticeSection(
                icon: Icons.compare_arrows_rounded,
                color: AppTheme.brandAmber,
                title: 'Match',
                child: _PairsView(
                  title: 'Match each item',
                  pairs: content.matchingActivity,
                ),
              ),
              _PracticeSection(
                icon: Icons.family_restroom_rounded,
                color: AppTheme.brandPink,
                title: 'For Parents',
                child: _buildParentsSection(context, content),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One collapsible row in the Lesson Detail "Practice & explore" section —
/// keeps Cards, Quiz, Memory, Match, and For Parents reachable without
/// competing with Story/Video for the primary tab selector.
class _PracticeSection extends StatelessWidget {
  const _PracticeSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .16),
            foregroundColor: color,
            child: Icon(icon, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [child],
        ),
      ),
    ),
  );
}

/// Gradient lesson header: an icon badge, colorful bubble title, summary,
/// and pill-shaped meta badges, matching the hero-banner language used
/// across every other screen in the app.
class _LessonMetaHeader extends StatelessWidget {
  const _LessonMetaHeader({required this.content, required this.request});
  final LessonContent content;
  final LessonRequest request;

  static const _difficultyIcons = {
    LessonDifficulty.easy: Icons.sentiment_satisfied_rounded,
    LessonDifficulty.medium: Icons.trending_up_rounded,
    LessonDifficulty.challenging: Icons.rocket_launch_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: AppTheme.heroGradient(context),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandViolet.withValues(alpha: .24),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: Colors.white.withValues(alpha: .25)),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LESSON',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: .85),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                ColorfulTitle(text: content.title, fontSize: 21),
                const SizedBox(height: 6),
                Text(
                  content.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: .92),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon:
                          _difficultyIcons[request.difficulty] ??
                          Icons.sentiment_satisfied_rounded,
                      label:
                          request.difficulty.name[0].toUpperCase() +
                          request.difficulty.name.substring(1),
                    ),
                    _MetaPill(
                      icon: Icons.schedule_rounded,
                      label: '${request.durationMinutes} min',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small translucent pill badge used to show a lesson's meta facts (
/// difficulty, duration) over the gradient [_LessonMetaHeader].
class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: .3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// The Story tab's reading pane: a paper-styled story card with a listen
/// button and a caregiver cue, echoing the Kombai "Guided Story" concept.
class _StoryReadingSurface extends StatelessWidget {
  const _StoryReadingSurface({
    required this.content,
    required this.onListen,
    required this.onStartLearning,
  });
  final LessonContent content;
  final VoidCallback onListen;
  final VoidCallback onStartLearning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'A calm story to read together.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onListen,
              tooltip: 'Read story aloud',
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: AppTheme.softShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.brandViolet,
                      AppTheme.brandPink,
                      AppTheme.brandCoral,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  content.story,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.brandViolet.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: AppTheme.brandViolet.withValues(alpha: .22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite_rounded, color: AppTheme.brandViolet),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Read this together, at whatever pace feels right today.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BouncyTap(
          scale: .97,
          child: FilledButton.icon(
            onPressed: onStartLearning,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start learning'),
          ),
        ),
      ],
    );
  }
}

class _AnimatedVideoView extends ConsumerStatefulWidget {
  const _AnimatedVideoView({required this.lesson, required this.child});

  final Lesson lesson;
  final ChildProfile? child;

  @override
  ConsumerState<_AnimatedVideoView> createState() => _AnimatedVideoViewState();
}

class _AnimatedVideoViewState extends ConsumerState<_AnimatedVideoView> {
  VideoPlayerController? _player;
  String? _playingUrl;
  int _sceneIndex = 0;
  String? _error;

  /// `video_player` only ships a working engine for web, Android, iOS, and
  /// macOS — there is no Windows or Linux desktop implementation, so
  /// attempting playback there hangs forever instead of erroring.
  static bool get _videoPlaybackSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _playScenes(List<GeneratedVideoScene> scenes) async {
    if (!_videoPlaybackSupported) return;
    final completed = scenes.where((scene) => scene.videoUrl != null).toList()
      ..sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));
    if (completed.isEmpty) return;
    if (_sceneIndex >= completed.length) _sceneIndex = 0;
    final url = completed[_sceneIndex].videoUrl!;
    if (_playingUrl == url && _player != null) return;
    await _player?.dispose();
    _playingUrl = url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = controller;
    try {
      await controller.initialize();
      await controller.play();
      controller.addListener(() {
        if (!controller.value.isInitialized) return;
        final position = controller.value.position;
        final duration = controller.value.duration;
        if (duration > Duration.zero && position >= duration) {
          _sceneIndex++;
          if (_sceneIndex < completed.length) {
            _playScenes(scenes);
          } else {
            _sceneIndex = 0;
          }
        }
      });
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not play the video scene.');
    }
  }

  Future<void> _start() async {
    final child = widget.child;
    if (child == null) {
      setState(() => _error = 'Choose a child to create this lesson video.');
      return;
    }
    setState(() => _error = null);
    try {
      await ref
          .read(videoJobControllerProvider.notifier)
          .start(widget.lesson, child);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _retry(String jobId) async {
    setState(() => _error = null);
    try {
      await ref
          .read(videoJobControllerProvider.notifier)
          .retry(widget.lesson, jobId);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  String _statusLabel(VideoGenerationStatus status) {
    switch (status) {
      case VideoGenerationStatus.queued:
        return 'Preparing your lesson video…';
      case VideoGenerationStatus.generating:
        return 'Creating animated scenes…';
      case VideoGenerationStatus.processing:
        return 'Processing the animation…';
      case VideoGenerationStatus.completed:
        return 'Video ready!';
      case VideoGenerationStatus.failed:
        return 'Video generation failed';
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(videoJobControllerProvider);
    final jobAsync = ref.watch(videoJobProvider(widget.lesson.id));

    return jobAsync.when(
      loading: () => const LoadingView(message: 'Checking video status…'),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(videoJobProvider(widget.lesson.id)),
      ),
      data: (job) {
        if (job == null) {
          return ListView(
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.brandViolet.withValues(alpha: .25),
                        AppTheme.brandPink.withValues(alpha: .25),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_display_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bring this lesson to life with an animated video.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: busy ? null : _start,
                icon: const GeminiSparkleIcon(),
                label: Text(
                  busy ? 'Starting video generation…' : 'Generate lesson video',
                ),
              ),
            ],
          );
        }

        if (job.status == VideoGenerationStatus.completed) {
          final currentSceneNumber = job.scenes.isEmpty
              ? null
              : job
                    .scenes[_sceneIndex.clamp(0, job.scenes.length - 1)]
                    .sceneNumber;
          final caption = widget.lesson.content.videoScript
              .where((scene) => scene.sceneNumber == currentSceneNumber)
              .firstOrNull
              ?.narration;

          if (!_videoPlaybackSupported) {
            return ListView(
              children: [
                const SizedBox(height: 24),
                Icon(
                  Icons.desktop_windows_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Video playback isn’t available on this device yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The lesson video finished rendering, but this platform '
                  'can’t play it back. Try the web or mobile app to '
                  'watch it, or read the scene below.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: Text(caption, textAlign: TextAlign.center),
                  ),
                ],
              ],
            );
          }

          _playScenes(job.scenes);
          final player = _player;
          final showCaptions = ref.watch(
            accessibilityProvider.select((value) => value.closedCaptions),
          );
          return ListView(
            children: [
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (player != null && player.value.isInitialized)
                    AspectRatio(
                      aspectRatio: player.value.aspectRatio,
                      child: VideoPlayer(player),
                    )
                  else
                    const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (showCaptions && caption != null && caption.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      color: Colors.black.withValues(alpha: .7),
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Scene ${_sceneIndex + 1} of ${job.scenes.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        }

        if (job.status == VideoGenerationStatus.failed) {
          return ListView(
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                job.errorMessage ?? 'The animated video could not be created.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You can still enjoy the story, flashcards, quiz, and activities below.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: busy ? null : () => _retry(job.id),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(busy ? 'Retrying…' : 'Retry video generation'),
              ),
            ],
          );
        }

        // queued, generating, or processing
        final steps = [
          VideoGenerationStatus.queued,
          VideoGenerationStatus.generating,
          VideoGenerationStatus.processing,
        ];
        final currentIndex = steps.indexOf(job.status);
        return ListView(
          children: [
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              _statusLabel(job.status),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...steps.indexed.map(
              (entry) => ListTile(
                leading: Icon(
                  entry.$1 <= currentIndex
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: entry.$1 <= currentIndex
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(_statusLabel(entry.$2)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Feel free to explore the other tabs while your video is created.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: flipped
          ? 'Answer: ${widget.card.back}. Tap to see the question.'
          : 'Question: ${widget.card.front}. Tap to reveal the answer.',
      excludeSemantics: true,
      child: Card(
        color: flipped ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        child: InkWell(
          onTap: () => setState(() => flipped = !flipped),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: SizedBox(
            height: 190,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(flipped),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        flipped ? 'ANSWER' : 'QUESTION',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        flipped ? widget.card.back : widget.card.front,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            flipped
                                ? 'Tap to see question'
                                : 'Tap to reveal answer',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PairsView extends StatelessWidget {
  const _PairsView({required this.title, required this.pairs});
  final String title;
  final List<ActivityPair> pairs;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      ...pairs.map(
        (pair) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _PairChip(
                      label: pair.left,
                      color: AppTheme.brandViolet,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.sync_alt_rounded,
                      color: AppTheme.brandCoral,
                    ),
                  ),
                  Expanded(
                    child: _PairChip(
                      label: pair.right,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Colored pill used for one side of a memory/matching pair.
class _PairChip extends StatelessWidget {
  const _PairChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(fontWeight: FontWeight.w800, color: color),
    ),
  );
}
