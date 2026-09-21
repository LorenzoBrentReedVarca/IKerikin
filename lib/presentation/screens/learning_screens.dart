import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome;
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
              // Grows the lesson shelf by one AI-suggested lesson per
              // calendar day, tailored to this child's disabilities,
              // challenges, and interests. Cheap to call on every build:
              // it no-ops once today's lesson already exists.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(dailyLessonControllerProvider.notifier)
                    .ensureToday(child);
              });
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
                  kicker: 'Your learning space',
                  title: 'Learn',
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
                kicker: 'AI lesson builder',
                title: 'Create a lesson',
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

enum _LessonMode { video, story, cards, quiz, memory, match, parents }

class _ModeInfo {
  const _ModeInfo(this.mode, this.icon, this.label, this.color);
  final _LessonMode mode;
  final IconData icon;
  final String label;
  final Color color;
}

const _kLessonModes = [
  _ModeInfo(
    _LessonMode.video,
    Icons.smart_display_rounded,
    'Watch',
    AppTheme.brandViolet,
  ),
  _ModeInfo(
    _LessonMode.story,
    Icons.auto_stories_rounded,
    'Story',
    AppTheme.brandTeal,
  ),
  _ModeInfo(
    _LessonMode.cards,
    Icons.style_rounded,
    'Cards',
    AppTheme.brandCoral,
  ),
  _ModeInfo(
    _LessonMode.quiz,
    Icons.quiz_rounded,
    'Quiz',
    AppTheme.brandAmber,
  ),
  _ModeInfo(
    _LessonMode.memory,
    Icons.psychology_rounded,
    'Memory',
    AppTheme.brandPink,
  ),
  _ModeInfo(
    _LessonMode.match,
    Icons.compare_arrows_rounded,
    'Match',
    AppTheme.brandViolet,
  ),
  _ModeInfo(
    _LessonMode.parents,
    Icons.family_restroom_rounded,
    'Parents',
    AppTheme.brandTeal,
  ),
];

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  _LessonMode _mode = _LessonMode.video;
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _storyVoice = AudioPlayer();
  final Map<int, int> _answers = {};
  int _minutes = 0;
  late final Stopwatch _stopwatch = Stopwatch()..start();
  late String? _storyNarrationUrl = widget.lesson.content.storyNarrationUrl;
  bool _storyNarrationLoading = false;

  @override
  void dispose() {
    _tts.stop();
    _storyVoice.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _setMode(_LessonMode mode) {
    if (mode == _mode) return;
    _tts.stop();
    _storyVoice.stop();
    setState(() => _mode = mode);
  }

  Future<void> _listenToStory(LessonContent content, ChildProfile? child) async {
    _tts.stop();
    // Fire-and-forget with a timeout: on Flutter web, stopping a player that
    // has never played anything can hang indefinitely instead of resolving.
    unawaited(_storyVoice.stop().timeout(const Duration(seconds: 2), onTimeout: () {}));
    if (_storyNarrationUrl != null) {
      try {
        await _storyVoice.play(UrlSource(_storyNarrationUrl!));
        return;
      } catch (_) {
        // Fall through to (re)synthesize or on-device TTS below.
      }
    }
    if (_storyNarrationLoading || child == null) {
      if (child == null) _tts.speak(content.story);
      return;
    }
    setState(() => _storyNarrationLoading = true);
    try {
      final url = await ref
          .read(lessonRepositoryProvider)
          .narrateStory(widget.lesson, child);
      if (!mounted) return;
      setState(() {
        _storyNarrationUrl = url;
        _storyNarrationLoading = false;
      });
      await _storyVoice.play(UrlSource(url));
    } catch (_) {
      if (mounted) setState(() => _storyNarrationLoading = false);
      _tts.speak(content.story);
    }
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

  Widget _buildMode(BuildContext context, LessonContent content, child) {
    switch (_mode) {
      case _LessonMode.video:
        return _AnimatedVideoView(
          key: const ValueKey('video'),
          lesson: widget.lesson,
          child: child,
          onPlaybackStart: () => _tts.stop(),
        );
      case _LessonMode.story:
        return _StoryReadingSurface(
          key: const ValueKey('story'),
          content: content,
          isNarrating: _storyNarrationLoading,
          onListen: () => _listenToStory(content, child),
          onStartLearning: () => _setMode(_LessonMode.video),
        );
      case _LessonMode.cards:
        return _CardsModeView(
          key: const ValueKey('cards'),
          cards: content.flashcards,
        );
      case _LessonMode.quiz:
        return _QuizModeView(
          key: const ValueKey('quiz'),
          questions: content.quiz,
          answers: _answers,
          onAnswer: (index, value) =>
              setState(() => _answers[index] = value),
        );
      case _LessonMode.memory:
        return _MemoryGameView(
          key: const ValueKey('memory'),
          pairs: content.memoryGame,
        );
      case _LessonMode.match:
        return _MatchGameView(
          key: const ValueKey('match'),
          pairs: content.matchingActivity,
        );
      case _LessonMode.parents:
        return _ParentPracticeView(
          key: const ValueKey('parents'),
          content: content,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.lesson.content;
    final child = activeChild(ref);
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
      // Hidden while the Watch tab is showing its empty "nothing made yet"
      // state — finishing the lesson before a video has even started
      // generating reads as broken, not as an available action.
      floatingActionButton:
          _mode == _LessonMode.video &&
              ref.watch(videoJobProvider(widget.lesson.id)).value == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _finish,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Finish'),
            ),
      body: SceneBackground(
        scene: SceneKind.learn,
        child: ResponsiveBody(
          maxWidth: 1300,
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 96),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LessonMetaHeader(
                  content: content,
                  request: widget.lesson.request,
                ),
                const SizedBox(height: 18),
                _ModeTabStrip(mode: _mode, onSelect: _setMode),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildMode(context, content, child),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of pill tabs for switching between the seven lesson
/// modes, matching Kombai's mode-tab pattern used across the activity
/// screens (wraps on narrow widths instead of scrolling).
class _ModeTabStrip extends StatelessWidget {
  const _ModeTabStrip({required this.mode, required this.onSelect});
  final _LessonMode mode;
  final ValueChanged<_LessonMode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final info in _kLessonModes)
          _ModeTabButton(
            info: info,
            selected: info.mode == mode,
            onTap: () => onSelect(info.mode),
          ),
      ],
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.info,
    required this.selected,
    required this.onTap,
  });
  final _ModeInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? info.color : scheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                info.icon,
                size: 18,
                color: selected ? Colors.white : info.color,
              ),
              const SizedBox(width: 8),
              Text(
                info.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared card shell every mode view renders inside, giving the mode
/// switcher a consistent frame (border + soft shadow) to animate between.
class _GentlePathPanel extends StatelessWidget {
  const _GentlePathPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius * 2),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: AppTheme.softShadow(context),
      ),
      child: child,
    );
  }
}

/// Small caps micro-label used above every section heading across the
/// lesson modes ("Practice together", "A gentle path", ...), matching
/// Kombai's "eyebrow" text treatment.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: color ?? AppTheme.brandViolet,
    ),
  );
}

/// Two-column layout every mode uses: the main practice area on the left
/// and a narrower "gentle path" side panel on the right, matching Kombai's
/// `practice-layout` pattern. Stacks to a single column on narrow widths
/// so it still works on phones.
class _SplitLayout extends StatelessWidget {
  const _SplitLayout({required this.main, required this.side});
  final Widget main;
  final Widget side;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, const SizedBox(height: 16), side],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: main),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: side),
          ],
        );
      },
    );
  }
}

/// The "gentle path" side panel shell: eyebrow + heading + optional
/// trailing note, then whatever content the mode supplies below.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.eyebrow,
    required this.title,
    this.trailing,
    required this.children,
  });
  final String eyebrow;
  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _GentlePathPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Eyebrow(eyebrow),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// A numbered row used throughout every side panel: a "gentle path" step,
/// a jump-to-card index entry, a storyboard scene, or a parent tip — the
/// same shape Kombai reuses across all seven mode screens.
class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.number,
    required this.title,
    required this.subtitle,
    this.trailingIcon,
    this.color = AppTheme.brandViolet,
    this.selected = false,
    this.done = false,
    this.onTap,
  });
  final String number;
  final String title;
  final String subtitle;
  final IconData? trailingIcon;
  final Color color;
  final bool selected;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color.withValues(alpha: .1) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: color, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? Colors.green.withValues(alpha: .16)
                      : color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: done ? Colors.green.shade700 : color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(
                  trailingIcon,
                  size: 18,
                  color: done
                      ? Colors.green.shade600
                      : selected
                      ? color
                      : scheme.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The soft "pause when your child notices a feeling" reminder bar shown
/// under the main practice area on every lesson mode.
class _CaregiverCue extends StatelessWidget {
  const _CaregiverCue(this.text, {this.icon = Icons.favorite_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.brandViolet.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.brandViolet.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.brandViolet, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiz Mode — one question at a time, matching Kombai's "Quiz Mode: One
/// Question At A Time" design instead of the old all-questions list.
class _QuizModeView extends StatefulWidget {
  const _QuizModeView({
    super.key,
    required this.questions,
    required this.answers,
    required this.onAnswer,
  });
  final List<QuizQuestion> questions;
  final Map<int, int> answers;
  final void Function(int index, int value) onAnswer;

  @override
  State<_QuizModeView> createState() => _QuizModeViewState();
}

class _QuizModeViewState extends State<_QuizModeView> {
  int _step = 0;

  void _jumpTo(int index) {
    if (index <= _step || widget.answers.containsKey(index - 1) || index == 0) {
      setState(() => _step = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const _GentlePathPanel(
        child: SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.quiz_rounded,
            title: 'No quiz yet',
            message: 'This lesson does not have any quiz questions.',
          ),
        ),
      );
    }
    final index = _step.clamp(0, widget.questions.length - 1);
    final question = widget.questions[index];
    final answer = widget.answers[index];
    final correct = answer == question.correctIndex;
    final answeredCount = widget.answers.length;
    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final hasNextQuestion = index + 1 < widget.questions.length;
    final VoidCallback? nextCallback = answer == null
        ? null
        : hasNextQuestion
        ? () => setState(() => _step = index + 1)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('A small moment to notice'),
        const SizedBox(height: 4),
        Text(
          'Choose what feels true.',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Read the choices aloud if that helps.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        _SplitLayout(
          main: _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Question ${index + 1} of ${widget.questions.length}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    if (question.difficulty.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.brandAmber.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          question.difficulty,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (index + 1) / widget.questions.length,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 18),
                const _Eyebrow('Look, listen, and notice'),
                const SizedBox(height: 6),
                Text(
                  question.question,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in question.options.indexed) ...[
                  _QuizAnswerOption(
                    letter: letters[option.$1 % letters.length],
                    label: option.$2,
                    selected: answer == option.$1,
                    correct:
                        answer != null && option.$1 == question.correctIndex,
                    wrong:
                        answer == option.$1 &&
                        option.$1 != question.correctIndex,
                    revealed: answer != null,
                    onTap: answer == null
                        ? () => widget.onAnswer(index, option.$1)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
                if (answer != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
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
                                ? 'That\'s right — nice noticing. ${question.explanation}'
                                : 'That\'s okay. ${question.explanation}',
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
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Read question aloud'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: nextCallback,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(hasNextQuestion ? 'Next question' : 'All done!'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          side: _SidePanel(
            eyebrow: 'Keep going gently',
            title: 'Your quiz path',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '$answeredCount',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.brandViolet,
                        ),
                  ),
                  Text(
                    '/${widget.questions.length}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Try, notice, and try again. Every answer helps.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final entry in widget.questions.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _PathRow(
                    number: '${entry.$1 + 1}',
                    title: 'Question ${entry.$1 + 1}',
                    subtitle: widget.answers.containsKey(entry.$1)
                        ? 'Answered'
                        : entry.$1 == index
                        ? 'Current'
                        : 'Not yet',
                    trailingIcon: widget.answers.containsKey(entry.$1)
                        ? Icons.check_circle_rounded
                        : entry.$1 == index
                        ? Icons.play_circle_fill_rounded
                        : Icons.circle_outlined,
                    done: widget.answers.containsKey(entry.$1),
                    selected: entry.$1 == index,
                    onTap: () => _jumpTo(entry.$1),
                  ),
                ),
            ],
          ),
        ),
        _CaregiverCue(
          'Read the choices slowly. If your child needs a pause, come back to this question whenever they are ready.',
        ),
      ],
    );
  }
}

class _QuizAnswerOption extends StatelessWidget {
  const _QuizAnswerOption({
    required this.letter,
    required this.label,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.revealed,
    required this.onTap,
  });
  final String letter;
  final String label;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool revealed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color border = scheme.outlineVariant;
    Color bg = scheme.surface;
    if (revealed && correct) {
      border = Colors.green.shade400;
      bg = Colors.green.withValues(alpha: .08);
    } else if (wrong) {
      border = scheme.error;
      bg = scheme.errorContainer.withValues(alpha: .5);
    } else if (selected) {
      border = AppTheme.brandViolet;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (revealed && correct)
                      ? Colors.green.withValues(alpha: .18)
                      : AppTheme.brandViolet.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: (revealed && correct)
                        ? Colors.green.shade700
                        : AppTheme.brandViolet,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (revealed && correct)
                Icon(Icons.check_circle_rounded, color: Colors.green.shade700)
              else if (wrong)
                Icon(Icons.cancel_rounded, color: scheme.error),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cards Mode — gentle flashcards the child taps to flip, with a mastery
/// counter and progress dots, matching Kombai's "Cards Mode" design.
class _CardsModeView extends StatefulWidget {
  const _CardsModeView({super.key, required this.cards});
  final List<Flashcard> cards;

  @override
  State<_CardsModeView> createState() => _CardsModeViewState();
}

class _CardsModeViewState extends State<_CardsModeView> {
  int _index = 0;
  bool _flipped = false;
  final Set<int> _mastered = {};

  void _go(int delta) {
    setState(() {
      _index = (_index + delta).clamp(0, widget.cards.length - 1);
      _flipped = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const _GentlePathPanel(
        child: SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.style_rounded,
            title: 'No cards yet',
            message: 'This lesson does not have any flashcards.',
          ),
        ),
      );
    }
    final card = widget.cards[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Cards · practice together'),
        const SizedBox(height: 4),
        Text(
          'Small cards, calm steps.',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('There is no rush. Every try is part of learning.'),
        const SizedBox(height: 14),
        _SplitLayout(
          main: _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Eyebrow('Flashcard ${_index + 1}'),
                        Text(
                          'Card ${_index + 1} of ${widget.cards.length}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _ScoreChip(
                      icon: Icons.check_circle_rounded,
                      label: '${_mastered.length} mastered',
                      color: AppTheme.brandCoral,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setState(() => _flipped = !_flipped),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Container(
                      key: ValueKey('$_index-$_flipped'),
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 220),
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _flipped
                              ? [AppTheme.brandTeal, AppTheme.brandViolet]
                              : [AppTheme.brandCoral, AppTheme.brandAmber],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radius * 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _flipped ? 'ANSWER' : 'QUESTION',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .8),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _flipped ? card.back : card.front,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _flipped
                        ? 'Tap to see the question'
                        : 'Tap to reveal the answer',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _index > 0 ? () => _go(-1) : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Back'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _mastered.add(_index));
                        if (_index + 1 < widget.cards.length) _go(1);
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('I know this'),
                    ),
                    TextButton.icon(
                      onPressed: _index + 1 < widget.cards.length
                          ? () => _go(1)
                          : null,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          side: _SidePanel(
            eyebrow: 'A gentle path',
            title: 'Card path',
            trailing: Text(
              '${_index + 1} of ${widget.cards.length}',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            children: [
              for (final entry in widget.cards.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _PathRow(
                    number: '${entry.$1 + 1}',
                    title: entry.$2.front,
                    subtitle: entry.$2.back,
                    trailingIcon: _mastered.contains(entry.$1)
                        ? Icons.check_circle_rounded
                        : entry.$1 == _index
                        ? Icons.play_circle_fill_rounded
                        : Icons.circle_outlined,
                    done: _mastered.contains(entry.$1),
                    selected: entry.$1 == _index,
                    onTap: () => setState(() {
                      _index = entry.$1;
                      _flipped = false;
                    }),
                  ),
                ),
            ],
          ),
        ),
        const _CaregiverCue(
          'Pause whenever your child needs a break. Name the idea together, then celebrate the trying.',
        ),
      ],
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// Memory Mode — a real flip-and-match game. Each [ActivityPair]'s `left`
/// and `right` become two distinct cards sharing a `pairIndex`; a match is
/// found when two flipped cards share that index (not identical text,
/// since our pairs are asymmetric — e.g. "brushing teeth" / "healthy
/// smile" — unlike Kombai's duplicate-icon mockup).
/// A small, friendly icon palette standing in for a picture on each memory
/// card. Both cards in a pair share the same icon (assigned by pair index)
/// so a child can match by picture as well as by reading the words —
/// matching Kombai's "emotion-icon + label" card face pattern.
const _kMemoryCardIcons = [
  Icons.wb_sunny_rounded,
  Icons.favorite_rounded,
  Icons.cloud_rounded,
  Icons.local_florist_rounded,
  Icons.star_rounded,
  Icons.water_drop_rounded,
  Icons.pets_rounded,
  Icons.eco_rounded,
  Icons.celebration_rounded,
  Icons.spa_rounded,
  Icons.emoji_emotions_rounded,
  Icons.self_improvement_rounded,
];

class _MemoryCard {
  _MemoryCard(this.pairIndex, this.label)
    : icon = _kMemoryCardIcons[pairIndex % _kMemoryCardIcons.length];
  final int pairIndex;
  final String label;
  final IconData icon;
  bool revealed = false;
  bool matched = false;
}

class _MemoryGameView extends StatefulWidget {
  const _MemoryGameView({super.key, required this.pairs});
  final List<ActivityPair> pairs;

  @override
  State<_MemoryGameView> createState() => _MemoryGameViewState();
}

class _MemoryGameViewState extends State<_MemoryGameView> {
  late List<_MemoryCard> _cards;
  final List<int> _flipped = [];
  int _moves = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cards = _build();
  }

  @override
  void didUpdateWidget(covariant _MemoryGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pairs, widget.pairs)) {
      _cards = _build();
      _flipped.clear();
      _moves = 0;
    }
  }

  List<_MemoryCard> _build() {
    final cards = <_MemoryCard>[
      for (final entry in widget.pairs.indexed) ...[
        _MemoryCard(entry.$1, entry.$2.left),
        _MemoryCard(entry.$1, entry.$2.right),
      ],
    ];
    cards.shuffle();
    return cards;
  }

  void _reset() => setState(() {
    _cards = _build();
    _flipped.clear();
    _moves = 0;
  });

  Future<void> _tap(int index) async {
    if (_busy ||
        _cards[index].revealed ||
        _cards[index].matched ||
        _flipped.length == 2) {
      return;
    }
    setState(() {
      _cards[index].revealed = true;
      _flipped.add(index);
    });
    if (_flipped.length < 2) return;
    _moves++;
    final a = _cards[_flipped[0]];
    final b = _cards[_flipped[1]];
    if (a.pairIndex == b.pairIndex) {
      setState(() {
        a.matched = true;
        b.matched = true;
        _flipped.clear();
      });
      return;
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      a.revealed = false;
      b.revealed = false;
      _flipped.clear();
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pairs.isEmpty) {
      return const _GentlePathPanel(
        child: SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.psychology_rounded,
            title: 'No pairs yet',
            message: 'This lesson does not have a memory game.',
          ),
        ),
      );
    }
    final matchedPairs = _cards.where((c) => c.matched).length ~/ 2;
    final done = matchedPairs == widget.pairs.length;
    final pathStep = done ? 2 : matchedPairs > 0 ? 1 : 0;
    const steps = [
      ('Notice the picture', 'Look at the shape and color.'),
      ('Name it', 'Say it together without needing to be sure.'),
      ('Celebrate the try', 'Every careful guess helps learning.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Memory · matching pairs'),
        const SizedBox(height: 4),
        Text(
          'Find each pair',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Turn over two cards at a time. Take your time noticing what each one shows.',
        ),
        const SizedBox(height: 14),
        _SplitLayout(
          main: _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _Eyebrow('Practice together'),
                    const Spacer(),
                    _ScoreChip(
                      icon: Icons.swap_horiz_rounded,
                      label: '$_moves moves',
                      color: AppTheme.brandTeal,
                    ),
                    const SizedBox(width: 8),
                    _ScoreChip(
                      icon: Icons.favorite_rounded,
                      label: '$matchedPairs / ${widget.pairs.length} pairs',
                      color: AppTheme.brandPink,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Start again'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Which pieces belong together?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose two cards. The matched pair stays open.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                if (done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.celebration_rounded,
                          color: AppTheme.brandPink,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'All pairs found! Great memory.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cards.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) => _MemoryCardTile(
                    card: _cards[index],
                    onTap: () => _tap(index),
                  ),
                ),
              ],
            ),
          ),
          side: _SidePanel(
            eyebrow: 'A gentle path',
            title: 'Support the try',
            children: [
              for (final entry in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _PathRow(
                    number: '${entry.$1 + 1}',
                    title: entry.$2.$1,
                    subtitle: entry.$2.$2,
                    color: AppTheme.brandTeal,
                    trailingIcon: entry.$1 < pathStep
                        ? Icons.check_circle_rounded
                        : entry.$1 == pathStep
                        ? Icons.play_circle_fill_rounded
                        : Icons.circle_outlined,
                    done: entry.$1 < pathStep,
                    selected: entry.$1 == pathStep,
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.brandTeal.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Text(
                      '$matchedPairs',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.brandTeal,
                          ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        matchedPairs == 1
                            ? 'One pair found. There are ${widget.pairs.length - 1} more gentle discoveries.'
                            : matchedPairs == 0
                            ? 'No pairs found yet. Take your time.'
                            : '$matchedPairs pairs found. Keep going gently.',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _CaregiverCue(
          'Memory is not a race. Let your child turn the cards over, name what they notice, and try again.',
        ),
      ],
    );
  }
}

class _MemoryCardTile extends StatelessWidget {
  const _MemoryCardTile({required this.card, required this.onTap});
  final _MemoryCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = card.revealed || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: card.matched
              ? Colors.green.withValues(alpha: .16)
              : shown
              ? AppTheme.brandTeal.withValues(alpha: .16)
              : AppTheme.brandViolet,
          border: card.matched
              ? Border.all(color: Colors.green.shade400, width: 1.5)
              : null,
        ),
        child: shown
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    card.icon,
                    size: 30,
                    color: card.matched
                        ? Colors.green.shade700
                        : AppTheme.brandViolet,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    card.label,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: card.matched
                          ? Colors.green.shade800
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              )
            : const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }
}

/// Match Mode — tap an item on the left, then its partner on the right,
/// matching Kombai's "Match Mode: Everyday Skills Match" design.
class _MatchGameView extends StatefulWidget {
  const _MatchGameView({super.key, required this.pairs});
  final List<ActivityPair> pairs;

  @override
  State<_MatchGameView> createState() => _MatchGameViewState();
}

class _MatchGameViewState extends State<_MatchGameView> {
  late List<int> _rightOrder;
  final Set<int> _matched = {};
  int? _selectedLeft;
  int? _wrongRight;

  @override
  void initState() {
    super.initState();
    _rightOrder = _shuffled();
  }

  @override
  void didUpdateWidget(covariant _MatchGameView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pairs, widget.pairs)) {
      _rightOrder = _shuffled();
      _matched.clear();
      _selectedLeft = null;
    }
  }

  List<int> _shuffled() =>
      List<int>.generate(widget.pairs.length, (i) => i)..shuffle();

  void _reset() => setState(() {
    _rightOrder = _shuffled();
    _matched.clear();
    _selectedLeft = null;
    _wrongRight = null;
  });

  void _tapRight(int pairIndex) {
    if (_selectedLeft == null || _matched.contains(pairIndex)) return;
    if (_selectedLeft == pairIndex) {
      setState(() {
        _matched.add(pairIndex);
        _selectedLeft = null;
      });
      return;
    }
    setState(() => _wrongRight = pairIndex);
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _wrongRight = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pairs.isEmpty) {
      return const _GentlePathPanel(
        child: SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.compare_arrows_rounded,
            title: 'No matches yet',
            message: 'This lesson does not have a matching activity.',
          ),
        ),
      );
    }
    final done = _matched.length == widget.pairs.length;
    final matchStep = _matched.isEmpty ? 0 : done ? 3 : 1;
    const steps = [
      ('Look at both sides', 'Notice each idea before choosing.'),
      ('Choose one pair', 'Tap the ideas that belong together.'),
      ('Say it together', 'Repeat the pair in a calm voice.'),
      ('Try again slowly', 'Every answer helps us learn.'),
    ];
    final lastMatched = _matched.isEmpty ? null : widget.pairs[_matched.last];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Practice · match'),
        const SizedBox(height: 4),
        Text(
          'What goes together?',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Make one gentle connection at a time. There is no rush to finish.',
        ),
        const SizedBox(height: 14),
        _SplitLayout(
          main: _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const _Eyebrow('Connect the ideas'),
                    const Spacer(),
                    _ScoreChip(
                      icon: Icons.link_rounded,
                      label: '${_matched.length} / ${widget.pairs.length} pairs',
                      color: AppTheme.brandAmber,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose one on each side.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.celebration_rounded,
                          color: AppTheme.brandAmber,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Everything matched!',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Play again'),
                        ),
                      ],
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          for (final entry in widget.pairs.indexed) ...[
                            _MatchChoiceTile(
                              badge: '${entry.$1 + 1}',
                              label: entry.$2.left,
                              subtitle: entry.$2.educationalConnection,
                              matched: _matched.contains(entry.$1),
                              selected: _selectedLeft == entry.$1,
                              color: AppTheme.brandViolet,
                              onTap: _matched.contains(entry.$1)
                                  ? null
                                  : () => setState(
                                      () => _selectedLeft = entry.$1,
                                    ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          for (final pairIndex in _rightOrder) ...[
                            _MatchChoiceTile(
                              badge: null,
                              icon: Icons.arrow_forward_rounded,
                              label: widget.pairs[pairIndex].right,
                              subtitle: '',
                              matched: _matched.contains(pairIndex),
                              selected: false,
                              wrong: _wrongRight == pairIndex,
                              color: AppTheme.brandTeal,
                              onTap: _matched.contains(pairIndex)
                                  ? null
                                  : () => _tapRight(pairIndex),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          side: _SidePanel(
            eyebrow: 'A gentle path',
            title: 'Try these steps',
            children: [
              for (final entry in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _PathRow(
                    number: '${entry.$1 + 1}',
                    title: entry.$2.$1,
                    subtitle: entry.$2.$2,
                    color: AppTheme.brandAmber,
                    trailingIcon: entry.$1 < matchStep
                        ? Icons.check_circle_rounded
                        : entry.$1 == matchStep
                        ? Icons.play_circle_fill_rounded
                        : Icons.circle_outlined,
                    done: entry.$1 < matchStep,
                    selected: entry.$1 == matchStep,
                  ),
                ),
              if (lastMatched != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.brandAmber.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chat_bubble_rounded,
                        size: 18,
                        color: AppTheme.brandAmber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(
                              context,
                            ).style.copyWith(fontSize: 12.5),
                            children: [
                              const TextSpan(
                                text: 'Say it aloud: ',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text:
                                    '"${lastMatched.left} goes with ${lastMatched.right}."',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const _CaregiverCue(
          'Pause when your child notices something. Name it together, then try the helpful step.',
        ),
      ],
    );
  }
}

class _MatchChoiceTile extends StatelessWidget {
  const _MatchChoiceTile({
    this.badge,
    this.icon,
    required this.label,
    this.subtitle = '',
    required this.matched,
    required this.selected,
    required this.color,
    required this.onTap,
    this.wrong = false,
  });
  final String? badge;
  final IconData? icon;
  final String label;
  final String subtitle;
  final bool matched;
  final bool selected;
  final bool wrong;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color border = scheme.outlineVariant;
    Color bg = scheme.surface;
    if (matched) {
      border = Colors.green.shade400;
      bg = Colors.green.withValues(alpha: .1);
    } else if (wrong) {
      border = scheme.error;
      bg = scheme.errorContainer.withValues(alpha: .5);
    } else if (selected) {
      border = color;
      bg = color.withValues(alpha: .1);
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              if (badge != null || icon != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: badge != null
                      ? Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        )
                      : Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (matched)
                Icon(Icons.check_circle_rounded, color: Colors.green.shade700)
              else
                Icon(Icons.circle_outlined, size: 18, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parent Practice — the daily activity and parent tips, matching
/// Kombai's "Parent Practice: Daily Activity UI" panel styling.
class _ParentPracticeView extends StatefulWidget {
  const _ParentPracticeView({super.key, required this.content});
  final LessonContent content;

  @override
  State<_ParentPracticeView> createState() => _ParentPracticeViewState();
}

class _ParentPracticeViewState extends State<_ParentPracticeView> {
  bool _done = false;
  static const _tipIcons = [
    Icons.visibility_rounded,
    Icons.tune_rounded,
    Icons.auto_awesome_rounded,
    Icons.chat_bubble_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final tips = widget.content.parentTips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('For parents · daily practice'),
        const SizedBox(height: 4),
        Text(
          'Practice together',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'One small activity to help your child notice, pause, and find a calm next step.',
        ),
        const SizedBox(height: 14),
        _SplitLayout(
          main: _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.brandTeal.withValues(alpha: .14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: AppTheme.brandTeal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Eyebrow(
                            'Daily activity',
                            color: AppTheme.brandTeal,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Name it, then try it together',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                        child: Text(
                          widget.content.dailyActivity,
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.brandPink.withValues(alpha: .06),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(
                      color: AppTheme.brandPink.withValues(alpha: .2),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.chat_bubble_rounded, color: AppTheme.brandPink),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Keep your voice slow and your words short. A pause is already a successful practice.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _done
                                ? 'You made space to practice.'
                                : 'Ready when your child is ready.',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            _done
                                ? 'This activity is saved for today.'
                                : 'You can repeat this activity as often as it helps.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _done = !_done),
                      icon: Icon(
                        _done
                            ? Icons.check_circle_rounded
                            : Icons.check_rounded,
                      ),
                      label: Text(
                        _done ? 'Completed today' : 'Mark today complete',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          side: _SidePanel(
            eyebrow: 'Support & notice',
            title: 'Small ways to help',
            children: [
              if (tips.isEmpty)
                const Text('No parent tips for this lesson yet.')
              else
                for (final entry in tips.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _PathRow(
                      number: '${entry.$1 + 1}',
                      title: entry.$2,
                      subtitle: '',
                      color: AppTheme.brandPink,
                      trailingIcon: _tipIcons[entry.$1 % _tipIcons.length],
                    ),
                  ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.brandViolet.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: AppTheme.brandViolet,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'A gentle reminder',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The goal isn\'t to get it perfect. It\'s to help your child notice one small feeling and know what to do next.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '— Your IKeriKin practice guide',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _CaregiverCue(
          'Pause when your child notices a feeling. Name it together, then try the calm next step at a pace that feels safe.',
        ),
      ],
    );
  }
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
    super.key,
    required this.content,
    required this.onListen,
    required this.onStartLearning,
    this.isNarrating = false,
  });
  final LessonContent content;
  final VoidCallback onListen;
  final VoidCallback onStartLearning;
  final bool isNarrating;

  static const _prompts = [
    ('Look at the words.', 'Take a moment before moving on.'),
    ('Talk about it.', 'Offer a word, or let your child point to one.'),
    ('Try it together.', 'Make it playful — there is no wrong way.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Story · read together'),
        const SizedBox(height: 4),
        Text(
          'A calm story to read together',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text('Move at your own pace. Pause, talk, and return anytime.'),
        const SizedBox(height: 14),
        _SplitLayout(
          main: _GentlePathPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'A quiet moment to notice.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: isNarrating ? null : onListen,
                        tooltip: 'Listen to the story',
                        icon: isNarrating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.volume_up_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
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
                            style: theme.textTheme.titleMedium?.copyWith(
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: BouncyTap(
                    scale: .97,
                    child: FilledButton.icon(
                      onPressed: onStartLearning,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Continue to watch'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          side: _SidePanel(
            eyebrow: 'Read together',
            title: 'Three gentle prompts',
            children: [
              for (final entry in _prompts.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _PathRow(
                    number: '${entry.$1 + 1}',
                    title: entry.$2.$1,
                    subtitle: entry.$2.$2,
                    color: AppTheme.brandPink,
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.brandAmber.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: AppTheme.brandAmber,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Try this: ask what your child noticed. There is no need to answer quickly.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const _CaregiverCue(
          'Read this together, at whatever pace feels right today.',
        ),
      ],
    );
  }
}

class _AnimatedVideoView extends ConsumerStatefulWidget {
  const _AnimatedVideoView({
    super.key,
    required this.lesson,
    required this.child,
    this.onPlaybackStart,
  });

  final Lesson lesson;
  final ChildProfile? child;

  /// Notified the first time the video actually starts playing, so the
  /// lesson page can stop its own "read story aloud" voice before the
  /// video's narration begins.
  final VoidCallback? onPlaybackStart;

  @override
  ConsumerState<_AnimatedVideoView> createState() => _AnimatedVideoViewState();
}

class _AnimatedVideoViewState extends ConsumerState<_AnimatedVideoView> {
  String? _error;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Eyebrow('Animated story'),
        const SizedBox(height: 4),
        Text(
          'Watch and learn together',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text('Pause whenever your child notices a feeling.'),
        const SizedBox(height: 14),
        _buildJobContent(context, busy, jobAsync),
        const _CaregiverCue(
          'Pause when your child notices a feeling. Name it together, then try the calm breath.',
        ),
      ],
    );
  }

  Widget _buildJobContent(
    BuildContext context,
    bool busy,
    AsyncValue<VideoGenerationJob?> jobAsync,
  ) {
    return jobAsync.when(
      loading: () => const LoadingView(message: 'Checking video status…'),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(videoJobProvider(widget.lesson.id)),
      ),
      data: (job) {
        if (job == null) {
          return _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
            ),
          );
        }

        if (job.status == VideoGenerationStatus.completed) {
          return _VideoScenePlayer(
            lesson: widget.lesson,
            scenes: job.scenes,
            onPlaybackStart: widget.onPlaybackStart,
          );
        }

        if (job.status == VideoGenerationStatus.failed) {
          return _GentlePathPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
            ),
          );
        }

        // queued, generating, or processing
        final steps = [
          VideoGenerationStatus.queued,
          VideoGenerationStatus.generating,
          VideoGenerationStatus.processing,
        ];
        final currentIndex = steps.indexOf(job.status);
        return _GentlePathPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
          ),
        );
      },
    );
  }
}

/// Plays a completed lesson video's scenes back to back with narration and
/// captions. Used both inline (embedded in the lesson tab) and, via
/// [_openFullscreen], as a maximized full-screen page — each hosts its own
/// independent player/TTS instance rather than sharing state across routes.
class _VideoScenePlayer extends ConsumerStatefulWidget {
  const _VideoScenePlayer({
    required this.lesson,
    required this.scenes,
    this.initialSceneIndex = 0,
    this.fullscreen = false,
    this.onClose,
    this.initiallyPlaying = false,
    this.onPlaybackStart,
  });

  final Lesson lesson;
  final List<GeneratedVideoScene> scenes;
  final int initialSceneIndex;

  /// True when this instance is the maximized full-screen page, which swaps
  /// the expand button for a close button and lets the video grow to fill
  /// the available space instead of a fixed embedded height.
  final bool fullscreen;
  final VoidCallback? onClose;

  /// True only when opening full screen from an embedded player that was
  /// already mid-playback, so that transition doesn't force a redundant
  /// second tap — every other entry point starts paused on the first frame
  /// until the learner taps play, like a YouTube thumbnail.
  final bool initiallyPlaying;

  /// Notified the first time this scene's audio actually starts playing.
  final VoidCallback? onPlaybackStart;

  @override
  ConsumerState<_VideoScenePlayer> createState() => _VideoScenePlayerState();
}

class _VideoScenePlayerState extends ConsumerState<_VideoScenePlayer> {
  VideoPlayerController? _player;
  String? _playingUrl;
  late int _sceneIndex = widget.initialSceneIndex;
  String? _error;

  /// True once the learner has tapped play at least once (or this instance
  /// inherited an already-playing state from an embedded player opening
  /// full screen). Nothing plays — video, narration, or music — before
  /// this, so opening a lesson never starts audio on its own.
  bool _playbackEngaged = false;
  bool _musicStarted = false;
  bool _narrationStartedForScene = false;

  /// Runway's clips are silent. Each scene's narration is normally a
  /// pre-rendered Gemini voice track (_voice); on-device TTS only covers
  /// scenes where that synthesis failed or hasn't completed yet.
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _voice = AudioPlayer();

  /// Soft, looping instrumental bed under the narration so the video feels
  /// like a song instead of a silent clip with a voice-over. A synthesized,
  /// royalty-free asset — not a real sung track.
  final AudioPlayer _music = AudioPlayer();

  List<GeneratedVideoScene> get _completed =>
      widget.scenes.where((scene) => scene.videoUrl != null).toList()
        ..sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));

  @override
  void initState() {
    super.initState();
    _playbackEngaged = widget.initiallyPlaying;
    _music
      ..setReleaseMode(ReleaseMode.loop)
      ..setVolume(0.22);
    _prepareCurrentScene(autoplay: widget.initiallyPlaying);
  }

  @override
  void dispose() {
    _player?.dispose();
    _tts.stop();
    _voice.dispose();
    _music.dispose();
    super.dispose();
  }

  /// Loads the current scene's video and shows its first frame. Playback,
  /// narration, and music only begin if [autoplay] is true — otherwise the
  /// scene sits paused, like a YouTube thumbnail, until the learner taps
  /// the play button.
  Future<void> _prepareCurrentScene({required bool autoplay}) async {
    final completed = _completed;
    if (completed.isEmpty) return;
    if (_sceneIndex >= completed.length) _sceneIndex = 0;
    final url = completed[_sceneIndex].videoUrl!;
    if (_playingUrl == url && _player != null) return;
    await _player?.dispose();
    _playingUrl = url;
    _narrationStartedForScene = false;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = controller;
    try {
      await controller.initialize();
      controller.addListener(_onPlayerTick);
      if (mounted) setState(() {});
      if (autoplay) await _beginPlayback();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not play the video scene.');
    }
  }

  void _onPlayerTick() {
    final controller = _player;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (duration > Duration.zero && position >= duration) _advanceScene();
  }

  Future<void> _advanceScene() async {
    if (_completed.isEmpty) return;
    _sceneIndex++;
    if (_sceneIndex >= _completed.length) _sceneIndex = 0;
    // Playback is already underway this session, so later scenes chain
    // automatically instead of pausing on every scene change.
    await _prepareCurrentScene(autoplay: _playbackEngaged);
  }

  /// Jumps to a scene picked from the storyboard side panel. Pauses first
  /// so switching scenes never leaves two clips' audio overlapping.
  Future<void> _selectScene(int index) async {
    if (index == _sceneIndex || index < 0 || index >= _completed.length) {
      return;
    }
    await _pausePlayback();
    setState(() => _sceneIndex = index);
    await _prepareCurrentScene(autoplay: false);
  }

  /// Starts (or resumes) this scene's video, narration, and music together
  /// — called the first time the learner taps play, and again for later
  /// scenes once playback is underway.
  Future<void> _beginPlayback() async {
    final controller = _player;
    if (controller == null) return;
    final firstEngagement = !_playbackEngaged;
    _playbackEngaged = true;
    await controller.play();
    if (!_musicStarted) {
      _musicStarted = true;
      await _music.play(AssetSource('audio/lesson_video_theme.wav'));
    } else {
      await _music.resume();
    }
    if (!_narrationStartedForScene) {
      _narrationStartedForScene = true;
      final completed = _completed;
      if (_sceneIndex < completed.length) _speakScene(completed[_sceneIndex]);
    } else {
      await _voice.resume();
    }
    if (firstEngagement) widget.onPlaybackStart?.call();
    if (mounted) setState(() {});
  }

  Future<void> _pausePlayback() async {
    await _player?.pause();
    await _voice.pause();
    await _music.pause();
    _tts.stop();
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayPause() async {
    final controller = _player;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await _pausePlayback();
    } else {
      await _beginPlayback();
    }
  }

  Future<void> _speakScene(GeneratedVideoScene scene) async {
    _tts.stop();
    // Fire-and-forget with a timeout: on Flutter web, stopping a player that
    // has never played anything can hang indefinitely instead of resolving.
    unawaited(_voice.stop().timeout(const Duration(seconds: 2), onTimeout: () {}));
    final narrationAudioUrl = scene.narrationAudioUrl;
    if (narrationAudioUrl != null) {
      try {
        await _voice.play(UrlSource(narrationAudioUrl));
        return;
      } catch (_) {
        // Fall through to on-device TTS below.
      }
    }
    final narration = widget.lesson.content.videoScript
        .where((videoScene) => videoScene.sceneNumber == scene.sceneNumber)
        .firstOrNull
        ?.narration;
    if (narration != null && narration.isNotEmpty) _tts.speak(narration);
  }

  Future<void> _openFullscreen() async {
    // The embedded player stays mounted underneath the full-screen route,
    // so without pausing it here both instances would play the same scene
    // at once — video and narration doubled.
    final wasPlaying = _player?.value.isPlaying ?? false;
    if (wasPlaying) await _pausePlayback();
    final orientationsToRestore = [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ];
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenVideoPage(
          lesson: widget.lesson,
          scenes: widget.scenes,
          initialSceneIndex: _sceneIndex,
          initiallyPlaying: wasPlaying,
        ),
      ),
    );
    await SystemChrome.setPreferredOrientations(orientationsToRestore);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed;
    final currentSceneNumber = completed.isEmpty
        ? null
        : completed[_sceneIndex.clamp(0, completed.length - 1)].sceneNumber;
    final caption = widget.lesson.content.videoScript
        .where((scene) => scene.sceneNumber == currentSceneNumber)
        .firstOrNull
        ?.narration;
    final player = _player;
    final ready = player != null && player.value.isInitialized;
    final isPlaying = ready && player.value.isPlaying;
    final showCaptions = ref.watch(
      accessibilityProvider.select((value) => value.closedCaptions),
    );

    final video = Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (ready)
          GestureDetector(
            onTap: _togglePlayPause,
            child: AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
          )
        else
          const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (ready && !isPlaying)
          Positioned.fill(
            child: Center(
              child: _RoundIconButton(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Play',
                iconSize: 34,
                onPressed: _togglePlayPause,
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: _RoundIconButton(
            icon: widget.fullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            tooltip: widget.fullscreen ? 'Exit full screen' : 'Full screen',
            onPressed: widget.fullscreen ? widget.onClose : _openFullscreen,
          ),
        ),
        if (showCaptions && caption != null && caption.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.black.withValues(alpha: .7),
            child: _KaraokeCaption(
              key: ValueKey(caption),
              text: caption,
              active: isPlaying,
            ),
          ),
      ],
    );

    if (widget.fullscreen) return video;

    final playerPanel = _GentlePathPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radius * 2),
            ),
            child: video,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Text(
                  'Scene ${_sceneIndex + 1} of ${completed.length}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (completed.length <= 1) return playerPanel;

    return _SplitLayout(
      main: playerPanel,
      side: _SidePanel(
        eyebrow: 'A gentle path',
        title: 'Scene storyboard',
        trailing: Text(
          '${_sceneIndex + 1} of ${completed.length}',
          style: TextStyle(
            fontSize: 12.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          for (final entry in completed.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _PathRow(
                number: '${entry.$1 + 1}',
                title: () {
                  final objective = widget.lesson.content.videoScript
                      .where(
                        (scene) => scene.sceneNumber == entry.$2.sceneNumber,
                      )
                      .firstOrNull
                      ?.educationalObjective;
                  return objective == null || objective.isEmpty
                      ? 'Scene ${entry.$1 + 1}'
                      : objective;
                }(),
                subtitle: entry.$2.status == VideoGenerationStatus.completed
                    ? 'Ready'
                    : 'Loading',
                trailingIcon: entry.$1 < _sceneIndex
                    ? Icons.check_circle_rounded
                    : entry.$1 == _sceneIndex
                    ? Icons.play_circle_fill_rounded
                    : Icons.circle_outlined,
                done: entry.$1 < _sceneIndex,
                selected: entry.$1 == _sceneIndex,
                onTap: () => _selectScene(entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small translucent circular icon button used for the video's full-screen
/// toggle, legible over both light and dark video frames.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 24,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    iconSize: iconSize,
    style: IconButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: .45),
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
    ),
    icon: Icon(icon),
  );
}

/// Full-screen host for [_VideoScenePlayer]: a black page that lets the
/// video grow to fill the available space instead of a fixed embedded
/// height, with a close button that pops back to the lesson.
class _FullscreenVideoPage extends StatelessWidget {
  const _FullscreenVideoPage({
    required this.lesson,
    required this.scenes,
    required this.initialSceneIndex,
    this.initiallyPlaying = false,
  });

  final Lesson lesson;
  final List<GeneratedVideoScene> scenes;
  final int initialSceneIndex;
  final bool initiallyPlaying;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: _VideoScenePlayer(
          lesson: lesson,
          scenes: scenes,
          initialSceneIndex: initialSceneIndex,
          fullscreen: true,
          initiallyPlaying: initiallyPlaying,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );
}

/// Karaoke-style caption that bounces through a narration line one word at
/// a time, roughly timed to average speech pace, instead of showing the
/// whole sentence as flat static text.
class _KaraokeCaption extends StatefulWidget {
  const _KaraokeCaption({
    super.key,
    required this.text,
    required this.active,
  });
  final String text;

  /// Whether the scene's narration is actually playing right now. The
  /// word-highlight timer only advances while this is true, so captions
  /// don't race ahead of the audio while the video is paused or still
  /// buffering — same fix as requiring a play tap before the video starts.
  final bool active;

  @override
  State<_KaraokeCaption> createState() => _KaraokeCaptionState();
}

class _KaraokeCaptionState extends State<_KaraokeCaption> {
  static const _perWord = Duration(milliseconds: 430);

  late final List<String> _words = widget.text
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  int _activeIndex = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active) _startTimer();
  }

  @override
  void didUpdateWidget(covariant _KaraokeCaption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _startTimer();
    } else if (!widget.active && oldWidget.active) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    if (_words.length <= 1) return;
    // MediaQuery (read inside prefersReducedMotion) isn't safely available
    // in initState, so this only ever runs from didChangeDependencies or
    // didUpdateWidget, both of which are called after dependencies exist.
    if (prefersReducedMotion(context)) return;
    _timer = Timer.periodic(_perWord, (timer) {
      if (!mounted) return;
      if (_activeIndex >= _words.length - 1) {
        timer.cancel();
        _timer = null;
        return;
      }
      setState(() => _activeIndex++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 6,
    runSpacing: 2,
    children: [
      for (final (index, word) in _words.indexed)
        AnimatedScale(
          scale: index == _activeIndex ? 1.3 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.elasticOut,
          child: Text(
            word,
            style: TextStyle(
              color: index == _activeIndex ? AppTheme.brandAmber : Colors.white,
              fontWeight: index == _activeIndex
                  ? FontWeight.w900
                  : FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
    ],
  );
}

