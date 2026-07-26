import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/accessibility/accessibility_settings.dart';
import '../../domain/models.dart';
import '../widgets/common_widgets.dart';
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
    final child = activeChild(ref);
    final lessons = child == null
        ? const <Lesson>[]
        : ref.watch(lessonsProvider(child.id)).value ?? const <Lesson>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Progress Dashboard')),
      body: ResponsiveBody(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => ErrorView(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(progressProvider(child.id)),
                    ),
                    data: (progress) => RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(progressProvider(child.id)),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Weekly',
                                label: Text('Weekly'),
                              ),
                              ButtonSegment(
                                value: 'Monthly',
                                label: Text('Monthly'),
                              ),
                              ButtonSegment(
                                value: 'All Time',
                                label: Text('All Time'),
                              ),
                            ],
                            selected: {_period},
                            onSelectionChanged: (periods) =>
                                setState(() => _period = periods.first),
                          ),
                          const SizedBox(height: 14),
                          Card(
                            color: const Color(0xFFF8F4FF),
                            child: ListTile(
                              leading: ChildAvatar(
                                name: child.name,
                                photoUrl: child.photoUrl,
                              ),
                              title: Text(
                                child.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                'Age ${child.age} • ${child.gender}',
                              ),
                              trailing: TextButton(
                                onPressed: () => context.go('/profile'),
                                child: const Text('Change Child'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ResponsiveGrid(
                            minItemWidth: 140,
                            childAspectRatio: 1.15,
                            children: [
                              MetricCard(
                                icon: Icons.task_alt_rounded,
                                value: '${progress.completedLessons}',
                                label: 'Completed',
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
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_period == 'Weekly')
                            _BarSection(
                              title: 'Minutes learned this week',
                              labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                              values: progress.weeklyMinutes,
                              suffix: 'm',
                            )
                          else if (_period == 'Monthly')
                            _BarSection(
                              title: 'Lessons completed by week',
                              labels: const ['W1', 'W2', 'W3', 'W4'],
                              values: progress.monthlyCompletions,
                              suffix: '',
                            )
                          else
                            _AllTimeSummary(progress: progress),
                          const SizedBox(height: 12),
                          ResponsiveGrid(
                            minItemWidth: 180,
                            childAspectRatio: 1.75,
                            children: [
                              MetricCard(
                                icon: Icons.timer_rounded,
                                value: '${progress.timeSpentMinutes}m',
                                label: 'Time spent',
                                color: Colors.blue,
                              ),
                              MetricCard(
                                icon: Icons.task_alt_rounded,
                                value: '${progress.completedToday}',
                                label: 'Activities today',
                                color: Colors.green,
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
                                label: 'Badges earned',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Badges',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (progress.badges.isEmpty)
                            const Card(
                              child: ListTile(
                                leading: Icon(Icons.lock_outline_rounded),
                                title: Text('First Step is ready to unlock'),
                                subtitle: Text(
                                  'Complete one lesson to earn it.',
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: progress.badges
                                  .map(
                                    (badge) => Chip(
                                      avatar: const Icon(
                                        Icons.workspace_premium_rounded,
                                      ),
                                      label: Text(badge),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (lessons.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const SectionHeading(
                              title: 'Recommended Next Lesson',
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(14),
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE9E0FF),
                                  child: Icon(Icons.menu_book_rounded),
                                ),
                                title: Text(
                                  lessons.first.content.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                subtitle: Text(
                                  '${lessons.first.request.difficulty.name} • ${lessons.first.request.durationMinutes} min\n${lessons.first.content.summary}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: FilledButton(
                                  onPressed: () => context.push(
                                    '/lesson/${lessons.first.id}',
                                    extra: lessons.first,
                                  ),
                                  child: const Text('Start'),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
      ),
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
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values.indexed
                    .map(
                      (entry) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${entry.$2}$suffix',
                                style: const TextStyle(fontSize: 10),
                              ),
                              const SizedBox(height: 4),
                              Flexible(
                                child: FractionallySizedBox(
                                  heightFactor: entry.$2 == 0
                                      ? .03
                                      : entry.$2 / max,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(labels[entry.$1]),
                            ],
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
      appBar: AppBar(title: const Text('Settings & accessibility')),
      body: ResponsiveBody(
        maxWidth: 760,
        child: ListView(
          children: [
            Text(
              'Accessibility',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  _SettingSwitch(
                    icon: Icons.format_size_rounded,
                    title: 'Large fonts',
                    subtitle: 'Increase text throughout the app',
                    value: settings.largeFonts,
                    onChanged: (v) => update(settings.copyWith(largeFonts: v)),
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
                    icon: Icons.touch_app_rounded,
                    title: 'Large buttons',
                    subtitle: 'Increase interactive target sizes',
                    value: settings.largeButtons,
                    onChanged: (v) =>
                        update(settings.copyWith(largeButtons: v)),
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
            const SizedBox(height: 20),
            Text('Language', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
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
            const SizedBox(height: 20),
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
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text('IKeriKin 1.0.0 • Made with care in the Philippines'),
            ),
          ],
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
      return const Scaffold(
        body: EmptyState(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Administrator access required',
          message: 'This area is protected by role-based access policies.',
        ),
      );
    final metrics = ref.watch(adminMetricsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('IKeriKin Administration')),
      body: ResponsiveBody(
        child: metrics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(adminMetricsProvider),
          ),
          data: (data) => ListView(
            children: [
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 5 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.25,
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
                  ButtonSegment(value: 'categories', label: Text('Categories')),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: ref.read(adminRepositoryProvider).getRecords(_section),
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return ErrorView(message: snapshot.error.toString());
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
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
                                      onPressed: () async {
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
    );
  }
}
