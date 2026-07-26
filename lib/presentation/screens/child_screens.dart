import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import '../widgets/common_widgets.dart';

/// Parent-facing overview of the selected child's learning profile.
class ChildProfileScreen extends ConsumerWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final childrenState = ref.watch(childrenProvider(user.id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Profile'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings and accessibility',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 900,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: childrenState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString()),
          data: (children) {
            if (children.isEmpty) {
              return EmptyState(
                icon: Icons.child_care_rounded,
                title: 'Create a child profile',
                message:
                    'Add the learner details used to personalize AI lessons.',
                action: FilledButton.icon(
                  onPressed: () => context.push('/children/new'),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Add child'),
                ),
              );
            }
            final selectedId = ref.watch(selectedChildProvider);
            final child =
                children.where((item) => item.id == selectedId).firstOrNull ??
                children.first;
            final progress = ref.watch(progressProvider(child.id)).value;
            return ListView(
              children: [
                _ProfileHero(child: child),
                const SizedBox(height: 14),
                Card(
                  color: const Color(0xFFF6F1FF),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE5D9FF),
                          child: Icon(Icons.track_changes_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Learning Goal',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                child.challenges.isEmpty
                                    ? 'Building confidence through personalized daily practice.'
                                    : 'Building confidence with ${child.challenges.take(2).join(' and ').toLowerCase()}.',
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => context.go('/learn'),
                          child: const Text('Lessons'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeading(title: 'About'),
                const SizedBox(height: 8),
                ResponsiveGrid(
                  minItemWidth: 260,
                  childAspectRatio: 2.6,
                  children: [
                    _ProfileFact(
                      icon: Icons.accessibility_new_rounded,
                      color: const Color(0xFF7347D8),
                      title: 'Disabilities',
                      value: _summary(child.disabilities),
                    ),
                    _ProfileFact(
                      icon: Icons.psychology_alt_rounded,
                      color: const Color(0xFF3285D6),
                      title: 'Learning Style',
                      value: _summary(child.learningStyles),
                    ),
                    _ProfileFact(
                      icon: Icons.favorite_rounded,
                      color: const Color(0xFFE83E75),
                      title: 'Challenges',
                      value: _summary(child.challenges),
                    ),
                    _ProfileFact(
                      icon: Icons.star_rounded,
                      color: const Color(0xFFFF8D28),
                      title: 'Interests',
                      value: _summary(child.interests),
                    ),
                    _ProfileFact(
                      icon: Icons.translate_rounded,
                      color: const Color(0xFF2E9B4C),
                      title: 'Preferred Language',
                      value: child.preferredLanguage,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionHeading(title: 'Progress Summary'),
                const SizedBox(height: 8),
                ResponsiveGrid(
                  minItemWidth: 135,
                  childAspectRatio: 1.35,
                  children: [
                    MetricCard(
                      icon: Icons.menu_book_rounded,
                      value: '${progress?.completedLessons ?? 0}',
                      label: 'Lessons',
                    ),
                    MetricCard(
                      icon: Icons.query_stats_rounded,
                      value: '${progress?.averageQuizScore.round() ?? 0}%',
                      label: 'Average',
                    ),
                    MetricCard(
                      icon: Icons.local_fire_department_rounded,
                      value: '${progress?.streakDays ?? 0}',
                      label: 'Day streak',
                      color: Colors.orange,
                    ),
                    MetricCard(
                      icon: Icons.workspace_premium_rounded,
                      value: '${progress?.badges.length ?? 0}',
                      label: 'Badges',
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SectionHeading(
                  title: 'Children Profiles',
                  action: TextButton.icon(
                    onPressed: () => context.push('/children'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: children.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == children.length) {
                        return OutlinedButton.icon(
                          onPressed: () => context.push('/children/new'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add child'),
                        );
                      }
                      final item = children[index];
                      return ChoiceChip(
                        selected: item.id == child.id,
                        onSelected: (_) => ref
                            .read(selectedChildProvider.notifier)
                            .select(item.id),
                        avatar: ChildAvatar(
                          name: item.name,
                          photoUrl: item.photoUrl,
                          radius: 18,
                        ),
                        label: Text('${item.name}\nAge ${item.age}'),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _summary(List<String> values) =>
      values.isEmpty ? 'Not specified' : values.take(3).join(', ');
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFFAF8FF),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChildAvatar(name: child.name, photoUrl: child.photoUrl, radius: 62),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Age ${child.age}  •  ${child.gender}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.translate_rounded, size: 18),
                      label: Text(child.preferredLanguage),
                    ),
                    Chip(
                      avatar: const Icon(Icons.cake_outlined, size: 18),
                      label: Text(
                        '${child.birthday.month}/${child.birthday.day}/${child.birthday.year}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.push('/children/${child.id}/edit', extra: child),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Lists, selects, edits, and deletes a parent's child profiles.
class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final children = ref.watch(childrenProvider(user.id));
    final selected = ref.watch(selectedChildProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Child profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/children/new'),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add child'),
      ),
      body: ResponsiveBody(
        child: children.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(childrenProvider(user.id)),
          ),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.family_restroom_rounded,
                  title: 'Create your first child profile',
                  message:
                      'Personalization starts with your child’s strengths, interests, and learning needs.',
                  action: FilledButton.icon(
                    onPressed: () => context.push('/children/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add child profile'),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final child = items[index];
                    return Card(
                      color: selected == child.id
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundImage: child.photoUrl == null
                              ? null
                              : NetworkImage(child.photoUrl!),
                          child: child.photoUrl == null
                              ? Text(child.name.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        title: Text(
                          child.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          'Age ${child.age} • ${child.preferredLanguage}\n${child.interests.take(3).join(' • ')}',
                        ),
                        isThreeLine: true,
                        onTap: () async {
                          await ref
                              .read(selectedChildProvider.notifier)
                              .select(child.id);
                          if (context.mounted) context.go('/home');
                        },
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'edit')
                              context.push(
                                '/children/${child.id}/edit',
                                extra: child,
                              );
                            if (action == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete ${child.name}?'),
                                  content: const Text(
                                    'This removes the profile and cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true)
                                await ref
                                    .read(childControllerProvider.notifier)
                                    .delete(user.id, child.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// Comprehensive create and edit form for child learning profiles.
class ChildFormScreen extends ConsumerStatefulWidget {
  const ChildFormScreen({super.key, this.child});
  final ChildProfile? child;
  @override
  ConsumerState<ChildFormScreen> createState() => _ChildFormScreenState();
}

class _ChildFormScreenState extends ConsumerState<ChildFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late DateTime _birthday;
  late String _gender;
  late String _language;
  late Set<String> _disabilities;
  late Set<String> _challenges;
  late Set<String> _interests;
  late Set<String> _styles;
  Uint8List? _photo;
  String _photoExtension = 'jpg';

  @override
  void initState() {
    super.initState();
    final child = widget.child;
    _name = TextEditingController(text: child?.name ?? '');
    _birthday =
        child?.birthday ??
        DateTime.now().subtract(const Duration(days: 365 * 6));
    _gender = child?.gender ?? 'Prefer not to say';
    _language = child?.preferredLanguage ?? 'English';
    _disabilities = {...?child?.disabilities};
    _challenges = {...?child?.challenges};
    _interests = {...?child?.interests};
    _styles = {...?child?.learningStyles};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _photoExtension = file.name.split('.').last.toLowerCase();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_interests.isEmpty || _styles.isEmpty) {
      showMessage(
        context,
        'Select at least one interest and one learning style.',
        error: true,
      );
      return;
    }
    final user = ref.read(authStateProvider).value!;
    final profile = ChildProfile(
      id:
          widget.child?.id ??
          ref.read(childControllerProvider.notifier).createId(),
      parentId: user.id,
      name: _name.text.trim(),
      birthday: _birthday,
      gender: _gender,
      preferredLanguage: _language,
      disabilities: _disabilities.toList(),
      challenges: _challenges.toList(),
      interests: _interests.toList(),
      learningStyles: _styles.toList(),
      photoUrl: widget.child?.photoUrl,
      createdAt: widget.child?.createdAt ?? DateTime.now(),
    );
    try {
      await ref
          .read(childControllerProvider.notifier)
          .save(
            parentId: user.id,
            child: profile,
            photoBytes: _photo,
            photoExtension: _photoExtension,
          );
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(childControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.child == null ? 'Add child profile' : 'Edit child profile',
        ),
      ),
      body: ResponsiveBody(
        maxWidth: 760,
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundImage: _photo != null
                          ? MemoryImage(_photo!)
                          : widget.child?.photoUrl != null
                          ? NetworkImage(widget.child!.photoUrl!)
                          : null,
                      child: _photo == null && widget.child?.photoUrl == null
                          ? const Icon(Icons.child_care_rounded, size: 52)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.camera_alt_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Child’s name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) => (value?.trim().length ?? 0) >= 2
                    ? null
                    : 'Enter the child’s name',
              ),
              const SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Birthday'),
                subtitle: Text(
                  '${_birthday.month}/${_birthday.day}/${_birthday.year}',
                ),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _birthday,
                    firstDate: DateTime(1995),
                    lastDate: DateTime.now(),
                  );
                  if (selected != null) setState(() => _birthday = selected);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_rounded),
                ),
                items: ['Female', 'Male', 'Non-binary', 'Prefer not to say']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _gender = value!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(
                  labelText: 'Preferred language',
                  prefixIcon: Icon(Icons.language_rounded),
                ),
                items: ProfileOptions.languages
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _language = value!),
              ),
              _ChoiceSection(
                title: 'Disabilities',
                subtitle:
                    'Select all that apply. This helps adapt content respectfully.',
                options: ProfileOptions.disabilities,
                selected: _disabilities,
                onChanged: (value) => setState(() => _disabilities = value),
              ),
              _ChoiceSection(
                title: 'Learning challenges',
                options: ProfileOptions.challenges,
                selected: _challenges,
                onChanged: (value) => setState(() => _challenges = value),
              ),
              _ChoiceSection(
                title: 'Interests',
                subtitle: 'Required for personalized stories and activities.',
                options: ProfileOptions.interests,
                selected: _interests,
                onChanged: (value) => setState(() => _interests = value),
              ),
              _ChoiceSection(
                title: 'Learning styles',
                subtitle: 'Choose at least one.',
                options: ProfileOptions.learningStyles,
                selected: _styles,
                onChanged: (value) => setState(() => _styles = value),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: Text(
                  widget.child == null ? 'Create profile' : 'Save changes',
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

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    this.subtitle,
    required this.options,
    required this.selected,
    required this.onChanged,
  });
  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(subtitle!),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: (enabled) {
                    final updated = {...selected};
                    enabled ? updated.add(option) : updated.remove(option);
                    onChanged(updated);
                  },
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}
