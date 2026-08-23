import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/decorative_scenes.dart';

/// Looks up any English word through the Free Dictionary API and displays
/// its phonetics, parts of speech, definitions, and examples so parents and
/// children can explore vocabulary encountered in lessons and flashcards.
class WordExplorerScreen extends ConsumerStatefulWidget {
  const WordExplorerScreen({super.key});

  @override
  ConsumerState<WordExplorerScreen> createState() => _WordExplorerScreenState();
}

class _WordExplorerScreenState extends ConsumerState<WordExplorerScreen> {
  final _controller = TextEditingController();
  final _tts = FlutterTts();

  @override
  void dispose() {
    _controller.dispose();
    _tts.stop();
    super.dispose();
  }

  void _search() {
    final word = _controller.text.trim();
    if (word.isEmpty) return;
    FocusScope.of(context).unfocus();
    ref.read(wordLookupControllerProvider.notifier).lookup(word);
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(wordLookupControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Explorer'),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: SceneBackground(
        scene: SceneKind.dictionary,
        child: ResponsiveBody(
          maxWidth: 820,
          padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeroBanner(
                icon: Icons.menu_book_rounded,
                title: 'Look up a word',
                colorfulTitle: true,
                subtitle:
                    'Powered by the Free Dictionary API — search any English '
                    'word to see phonetics, meanings, and examples.',
              ),
              const SizedBox(height: 16),
              _SearchField(controller: _controller, onSubmitted: _search),
              const SizedBox(height: 8),
              _WordSuggestions(controller: _controller, onSearch: _search),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: result.when(
                    data: (definition) => definition == null
                        ? const EmptyState(
                            key: ValueKey('empty'),
                            icon: Icons.travel_explore_rounded,
                            title: 'Search a word to begin',
                            message:
                                'Results include phonetics, parts of speech, '
                                'definitions, and example sentences.',
                          )
                        : _WordResult(
                            key: ValueKey(definition.word),
                            definition: definition,
                            tts: _tts,
                          ),
                    loading: () => const LoadingView(
                      key: ValueKey('loading'),
                      message: 'Looking up word…',
                    ),
                    error: (error, _) => ErrorView(
                      key: const ValueKey('error'),
                      message: error.toString(),
                      onRetry: _search,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandViolet.withValues(alpha: .18),
            blurRadius: 26,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSubmitted(),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: 'Word',
          hintText: 'e.g. resilience',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(6),
            child: FilledButton.icon(
              onPressed: onSubmitted,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Search'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minHeight: 40,
            minWidth: 120,
          ),
        ),
      ),
    );
  }
}

class _WordSuggestions extends StatelessWidget {
  const _WordSuggestions({required this.controller, required this.onSearch});
  final TextEditingController controller;
  final VoidCallback onSearch;

  static const _words = [
    'resilience',
    'serendipity',
    'empathy',
    'curiosity',
    'wonder',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _words.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Try:',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          final word = _words[index - 1];
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(word),
            onPressed: () {
              controller.text = word;
              onSearch();
            },
          );
        },
      ),
    );
  }
}

class _WordResult extends StatelessWidget {
  const _WordResult({super.key, required this.definition, required this.tts});
  final WordDefinition definition;
  final FlutterTts tts;

  static const _partColors = {
    'noun': AppTheme.brandViolet,
    'verb': AppTheme.brandCoral,
    'adjective': AppTheme.brandTeal,
    'adverb': AppTheme.brandAmber,
    'pronoun': AppTheme.brandPink,
    'preposition': AppTheme.brandTeal,
    'conjunction': AppTheme.brandCoral,
    'interjection': AppTheme.brandPink,
  };

  Color _accentFor(String part) =>
      _partColors[part.toLowerCase()] ?? AppTheme.brandViolet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius + 4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.brandViolet.withValues(alpha: .18),
                AppTheme.brandPink.withValues(alpha: .12),
                AppTheme.brandCoral.withValues(alpha: .10),
              ],
            ),
            border: Border.all(
              color: AppTheme.brandViolet.withValues(alpha: .25),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandViolet.withValues(alpha: .22),
                blurRadius: 32,
                offset: const Offset(0, 16),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.word,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (definition.phonetic.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          definition.phonetic,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.heroGradient(context),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandPink.withValues(alpha: .45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () => tts.speak(definition.word),
                  tooltip: 'Listen',
                  iconSize: 24,
                  color: Colors.white,
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final meaning in definition.meanings) ...[
          _MeaningCard(
            meaning: meaning,
            accent: _accentFor(meaning.partOfSpeech),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MeaningCard extends StatelessWidget {
  const _MeaningCard({required this.meaning, required this.accent});
  final WordMeaning meaning;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: .22),
                    accent.withValues(alpha: .10),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accent.withValues(alpha: .35)),
              ),
              child: Text(
                meaning.partOfSpeech,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in meaning.definitions.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2, right: 10),
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .18),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.$1 + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(entry.$2, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
            for (final example in meaning.examples)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: accent, width: 3)),
                  ),
                  child: Text(
                    '“$example”',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
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
