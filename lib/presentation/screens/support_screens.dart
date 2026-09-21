import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/accessibility/accessibility_settings.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/decorative_scenes.dart';
import 'learning_screens.dart';

/// Child progress dashboard with weekly and monthly trends.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  String _period = 'Weekly';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final child = activeChild(ref);
    final children = user == null
        ? const <ChildProfile>[]
        : ref.watch(childrenProvider(user.id)).value ?? const <ChildProfile>[];
    final lessons = child == null
        ? const <Lesson>[]
        : ref.watch(lessonsProvider(child.id)).value ?? const <Lesson>[];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SceneBackground(
        scene: SceneKind.progress,
        child: ResponsiveBody(
          maxWidth: 1600,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: child == null
              ? const EmptyState(
                  icon: Icons.insights_rounded,
                  title: 'No progress yet',
                  message:
                      'Select or create a child profile to track learning progress.',
                )
              : ref
                    .watch(progressProvider(child.id))
                    .when(
                      loading: () =>
                          const LoadingView(message: 'Loading progress…'),
                      error: (error, _) => ErrorView(
                        message: error.toString(),
                        onRetry: () =>
                            ref.invalidate(progressProvider(child.id)),
                      ),
                      data: (progress) => RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(progressProvider(child.id)),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            HeroBanner(
                              kicker: 'Learning progress',
                              title: 'Progress',
                              subtitle:
                                  'A calm view of what ${child.name} has practiced and what comes next.',
                            ),
                            const SizedBox(height: 18),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final learnerColumn = _ProgressLearnerColumn(
                                  child: child,
                                  children: children,
                                  completedToday: progress.completedToday,
                                );
                                final recordColumn = _ProgressRecordColumn(
                                  child: child,
                                  progress: progress,
                                  period: _period,
                                  onPeriodChanged: (value) =>
                                      setState(() => _period = value),
                                  nextLesson: lessons.firstOrNull,
                                );
                                if (constraints.maxWidth < 820) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      learnerColumn,
                                      const SizedBox(height: 26),
                                      recordColumn,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(width: 260, child: learnerColumn),
                                    const SizedBox(width: 36),
                                    Expanded(child: recordColumn),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

/// "Selected learner" panel plus today's activity count, echoing the
/// Kombai "Story Path Evidence" progress concept.
class _ProgressLearnerColumn extends ConsumerWidget {
  const _ProgressLearnerColumn({
    required this.child,
    required this.children,
    required this.completedToday,
  });
  final ChildProfile child;
  final List<ChildProfile> children;
  final int completedToday;

  static const _dailyTarget = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = completedToday.clamp(0, _dailyTarget);
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
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
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
                children: [
                  ChildAvatar(
                    name: child.name,
                    photoUrl: child.photoUrl,
                    gender: child.gender,
                    radius: 24,
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
                        const SizedBox(height: 2),
                        Text(
                          '${timeOfDayGreeting()}, learner.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (children.length > 1) ...[
                const SizedBox(height: 14),
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
        const SizedBox(height: 20),
        Text(
          'TODAY',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedCounter(
              value: completedToday,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'activities today',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < _dailyTarget; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOut,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < done
                        ? AppTheme.brandTeal
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Today’s count is shown separately from the longer-term record.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Period selector, trend chart, evidence grid, and next-lesson
/// recommendation, echoing the Kombai "Story Path Evidence" progress
/// concept.
class _ProgressRecordColumn extends StatelessWidget {
  const _ProgressRecordColumn({
    required this.child,
    required this.progress,
    required this.period,
    required this.onPeriodChanged,
    required this.nextLesson,
  });
  final ChildProfile child;
  final ProgressSummary progress;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final Lesson? nextLesson;

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
                    'LEARNING RECORD',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Learning progress for ${child.name}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/profile'),
              icon: const Icon(Icons.north_east_rounded, size: 16),
              label: const Text(
                'View profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Weekly', label: Text('Weekly')),
            ButtonSegment(value: 'Monthly', label: Text('Monthly')),
            ButtonSegment(value: 'All Time', label: Text('All time')),
          ],
          selected: {period},
          showSelectedIcon: false,
          onSelectionChanged: (values) => onPeriodChanged(values.first),
        ),
        const SizedBox(height: 18),
        if (period == 'Weekly')
          _BarSection(
            title: 'Minutes learned this week',
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
            values: progress.weeklyMinutes,
            suffix: 'm',
          )
        else if (period == 'Monthly')
          _BarSection(
            title: 'Lessons completed by week',
            labels: const ['W1', 'W2', 'W3', 'W4'],
            values: progress.monthlyCompletions,
            suffix: '',
          )
        else
          _AllTimeSummary(progress: progress),
        const SizedBox(height: 24),
        Text(
          'What this record shows',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minItemWidth: 140,
          itemHeight: 136,
          children: [
            MetricCard(
              icon: Icons.task_alt_rounded,
              value: '${progress.completedLessons}',
              label: 'Lessons completed',
            ),
            MetricCard(
              icon: Icons.quiz_rounded,
              value: '${progress.averageQuizScore.round()}%',
              label: 'Quiz average',
              color: Colors.teal,
            ),
            MetricCard(
              icon: Icons.star_rounded,
              value: '${progress.xp}',
              label: 'XP earned',
              color: Colors.amber,
            ),
            MetricCard(
              icon: Icons.monetization_on_rounded,
              value: '${progress.coins}',
              label: 'Coins earned',
              color: Colors.orange,
            ),
            MetricCard(
              icon: Icons.local_fire_department_rounded,
              value: '${progress.streakDays} days',
              label: 'Current streak',
              color: Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Badges',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (progress.badges.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('First Step is ready to unlock'),
              subtitle: Text('Complete one lesson to earn it.'),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: progress.badges
                .map(
                  (badge) => Chip(
                    avatar: const Icon(Icons.workspace_premium_rounded),
                    label: Text(badge),
                  ),
                )
                .toList(),
          ),
        if (nextLesson != null) ...[
          const SizedBox(height: 24),
          HoverLift(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: AppTheme.softShadow(context),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECOMMENDED NEXT LESSON',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.brandViolet,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextLesson!.content.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextLesson!.content.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              nextLesson!.request.difficulty.name,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${nextLesson!.request.durationMinutes} min',
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
                  const SizedBox(width: 12),
                  BouncyTap(
                    scale: .97,
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        '/lesson/${nextLesson!.id}',
                        extra: nextLesson,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Open lesson'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AllTimeSummary extends StatelessWidget {
  const _AllTimeSummary({required this.progress});

  final ProgressSummary progress;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All-time learning',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryValue(
                  value: '${progress.completedLessons}',
                  label: 'Lessons',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  value: '${progress.timeSpentMinutes}m',
                  label: 'Learning time',
                ),
              ),
              Expanded(
                child: _SummaryValue(
                  value: '${progress.averageQuizScore.round()}%',
                  label: 'Quiz average',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(label, textAlign: TextAlign.center),
    ],
  );
}

class _BarSection extends StatelessWidget {
  const _BarSection({
    required this.title,
    required this.labels,
    required this.values,
    required this.suffix,
  });
  final String title;
  final List<String> labels;
  final List<int> values;
  final String suffix;
  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(
      1,
      (current, value) => value > current ? value : current,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values.indexed
                    .map(
                      (entry) => Expanded(
                        child: Semantics(
                          label:
                              '${labels[entry.$1]}: ${entry.$2}${suffix.isEmpty ? '' : ' $suffix'}',
                          excludeSemantics: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${entry.$2}$suffix',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey('${entry.$1}-${entry.$2}'),
                                    tween: Tween(
                                      begin: 0,
                                      end: entry.$2 == 0 ? .03 : entry.$2 / max,
                                    ),
                                    duration: const Duration(milliseconds: 700),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, heightFactor, child) =>
                                        FractionallySizedBox(
                                          heightFactor: heightFactor,
                                          child: child,
                                        ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: entry.$2 == 0
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  labels[entry.$1],
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Complete accessibility, language, account, and app settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilityProvider);
    final locale = ref.watch(localeProvider);
    void update(AccessibilitySettings value) =>
        ref.read(accessibilityProvider.notifier).update(value);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: AuroraBackground(
        child: ResponsiveBody(
          maxWidth: 900,
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: ListView(
            children: [
              const HeroBanner(
                kicker: 'Preferences',
                title: 'Settings & accessibility',
                subtitle: 'Tune how IKeriKin looks, sounds, and responds.',
              ),
              const SizedBox(height: 16),
              const SectionHeading(
                title: 'Reading & vision',
                subtitle: 'Make text and colors easier to see',
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _SettingSwitch(
                      icon: Icons.format_size_rounded,
                      title: 'Large fonts',
                      subtitle: 'Increase text throughout the app',
                      value: settings.largeFonts,
                      onChanged: (v) =>
                          update(settings.copyWith(largeFonts: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.text_fields_rounded,
                      title: 'Dyslexia-friendly font',
                      subtitle: 'Use Atkinson Hyperlegible',
                      value: settings.dyslexiaFont,
                      onChanged: (v) =>
                          update(settings.copyWith(dyslexiaFont: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.contrast_rounded,
                      title: 'High contrast',
                      subtitle: 'Increase color and border contrast',
                      value: settings.highContrast,
                      onChanged: (v) =>
                          update(settings.copyWith(highContrast: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark mode',
                      subtitle: 'Use a low-light color theme',
                      value: settings.darkMode,
                      onChanged: (v) => update(settings.copyWith(darkMode: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeading(
                title: 'Sound & motion',
                subtitle: 'Control audio support and animations',
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    _SettingSwitch(
                      icon: Icons.motion_photos_off_rounded,
                      title: 'Reduced motion',
                      subtitle: 'Remove page transition animations',
                      value: settings.reducedMotion,
                      onChanged: (v) =>
                          update(settings.copyWith(reducedMotion: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.record_voice_over_rounded,
                      title: 'Voice navigation',
                      subtitle: 'Enable spoken navigation support',
                      value: settings.voiceNavigation,
                      onChanged: (v) =>
                          update(settings.copyWith(voiceNavigation: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.volume_up_rounded,
                      title: 'Text to speech',
                      subtitle: 'Read lesson content aloud',
                      value: settings.textToSpeech,
                      onChanged: (v) =>
                          update(settings.copyWith(textToSpeech: v)),
                    ),
                    _SettingSwitch(
                      icon: Icons.closed_caption_rounded,
                      title: 'Closed captions',
                      subtitle: 'Show captions for future media lessons',
                      value: settings.closedCaptions,
                      onChanged: (v) =>
                          update(settings.copyWith(closedCaptions: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeading(
                title: 'Touch',
                subtitle: 'Adjust how big the controls are',
              ),
              const SizedBox(height: 8),
              Card(
                child: _SettingSwitch(
                  icon: Icons.touch_app_rounded,
                  title: 'Large buttons',
                  subtitle: 'Increase interactive target sizes',
                  value: settings.largeButtons,
                  onChanged: (v) => update(settings.copyWith(largeButtons: v)),
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeading(
                title: 'Language',
                subtitle: 'Choose the language used across the app',
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      value: 'en',
                      groupValue: locale.languageCode,
                      title: const Text('English'),
                      onChanged: (value) => ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(value!)),
                    ),
                    RadioListTile<String>(
                      value: 'fil',
                      groupValue: locale.languageCode,
                      title: const Text('Filipino'),
                      onChanged: (value) => ref
                          .read(localeProvider.notifier)
                          .setLocale(Locale(value!)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeading(
                title: 'Help',
                subtitle: 'Get familiar with how IKeriKin works',
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.school_rounded),
                  title: const Text('App tutorial'),
                  subtitle: const Text(
                    'Replay the narrated walkthrough of IKeriKin',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/tutorial'),
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () async {
                  await FlutterTts().speak(
                    'Welcome to IKeriKin. Your accessibility settings are ready.',
                  );
                },
                icon: const Icon(Icons.hearing_rounded),
                label: const Text('Test text to speech'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      icon: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out?'),
                      content: const Text(
                        'You will need to sign in again to reach your child profiles and lessons.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Stay signed in'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'IKeriKin 1.0.0 • Made with care in the Philippines',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

/// Restricted administrator dashboard for operational management.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _section = 'profiles';
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user?.role != UserRole.administrator)
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const AuroraBackground(
          child: EmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Administrator access required',
            message: 'This area is protected by role-based access policies.',
          ),
        ),
      );
    final metrics = ref.watch(adminMetricsProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: AuroraBackground(
        child: ResponsiveBody(
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: metrics.when(
            loading: () => const LoadingView(message: 'Loading metrics…'),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(adminMetricsProvider),
            ),
            data: (data) => ListView(
              children: [
                const HeroBanner(
                  kicker: 'Administration',
                  title: 'IKeriKin Administration',
                  subtitle: 'Operational metrics and record management.',
                ),
                const SizedBox(height: 16),
                ResponsiveGrid(
                  minItemWidth: 150,
                  itemHeight: 136,
                  children: [
                    MetricCard(
                      icon: Icons.people_rounded,
                      value: '${data.users}',
                      label: 'Users',
                    ),
                    MetricCard(
                      icon: Icons.child_care_rounded,
                      value: '${data.children}',
                      label: 'Children',
                    ),
                    MetricCard(
                      icon: Icons.menu_book_rounded,
                      value: '${data.lessons}',
                      label: 'Lessons',
                    ),
                    MetricCard(
                      icon: Icons.task_alt_rounded,
                      value: '${data.completedLessons}',
                      label: 'Completed',
                    ),
                    MetricCard(
                      icon: Icons.flag_rounded,
                      value: '${data.openReports}',
                      label: 'Open reports',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'profiles', label: Text('Users')),
                    ButtonSegment(value: 'children', label: Text('Children')),
                    ButtonSegment(value: 'lessons', label: Text('Lessons')),
                    ButtonSegment(value: 'reports', label: Text('Reports')),
                    ButtonSegment(
                      value: 'categories',
                      label: Text('Categories'),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) =>
                      setState(() => _section = value.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 18),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref
                      .read(adminRepositoryProvider)
                      .getRecords(_section),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return ErrorView(message: snapshot.error.toString());
                    if (!snapshot.hasData)
                      return const LoadingView(message: 'Loading records…');
                    if (snapshot.data!.isEmpty)
                      return const EmptyState(
                        icon: Icons.inbox_rounded,
                        title: 'No records',
                        message: 'No records are available in this section.',
                      );
                    return Card(
                      child: Column(
                        children: snapshot.data!
                            .map(
                              (record) => ListTile(
                                title: Text(
                                  (record['display_name'] ??
                                          record['name'] ??
                                          record['title'] ??
                                          record['id'])
                                      .toString(),
                                ),
                                subtitle: Text(
                                  (record['email'] ??
                                          record['status'] ??
                                          record['created_at'] ??
                                          '')
                                      .toString(),
                                ),
                                trailing: _section == 'profiles'
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: 'Delete record',
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) => AlertDialog(
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                              title: const Text(
                                                'Delete this record?',
                                              ),
                                              content: const Text(
                                                'This action cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        false,
                                                      ),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        dialogContext,
                                                        true,
                                                      ),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true) return;
                                          await ref
                                              .read(adminRepositoryProvider)
                                              .deleteRecord(
                                                _section,
                                                record['id'].toString(),
                                              );
                                          setState(() {});
                                        },
                                      ),
                              ),
                            )
                            .toList(),
                      ),
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
