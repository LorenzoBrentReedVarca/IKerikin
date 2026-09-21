import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../core/theme/app_theme.dart';

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.audioUrl,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String audioUrl;
}

const _kTutorialAssetBase =
    'https://pnienrjbdopfkedfeuhn.supabase.co/storage/v1/object/public/lesson-videos/tutorial';

const _tutorialSteps = [
  _TutorialStep(
    icon: Icons.favorite_rounded,
    color: AppTheme.brandPink,
    title: 'Welcome to IKeriKin',
    body:
        'IKeriKin means "I care for your kin." Every lesson here is built '
        'around your child — their interests, their pace, and the support '
        'they need. Let\'s take a quick look around.',
    audioUrl: '$_kTutorialAssetBase/welcome.wav',
  ),
  _TutorialStep(
    icon: Icons.child_care_rounded,
    color: AppTheme.brandViolet,
    title: 'Start with your child\'s profile',
    body:
        'Add your child\'s name, interests, and any disabilities or '
        'challenges they experience. The moment you save it, IKeriKin '
        'automatically creates a starter set of lessons made just for '
        'them — no waiting, no extra steps.',
    audioUrl: '$_kTutorialAssetBase/add-child.wav',
  ),
  _TutorialStep(
    icon: Icons.home_rounded,
    color: AppTheme.brandTeal,
    title: 'Your home screen',
    body:
        'Home shows today\'s learning path and quick access to switch '
        'between your children if you have more than one. Everything '
        'picks up right where your family left off.',
    audioUrl: '$_kTutorialAssetBase/home.wav',
  ),
  _TutorialStep(
    icon: Icons.auto_stories_rounded,
    color: AppTheme.brandAmber,
    title: 'Browse or create lessons',
    body:
        'The Lessons tab holds everything already made for your child, '
        'organized by skill. Tap Create to build a brand-new lesson '
        'around any goal you choose, like brushing teeth or sharing toys.',
    audioUrl: '$_kTutorialAssetBase/lessons.wav',
  ),
  _TutorialStep(
    icon: Icons.style_rounded,
    color: AppTheme.brandCoral,
    title: 'Inside every lesson',
    body:
        'Each lesson has several ways to learn: an animated video, a calm '
        'story you can listen to together, flashcards, a quiz, and '
        'matching games. There are also tips written just for parents.',
    audioUrl: '$_kTutorialAssetBase/inside-lesson.wav',
  ),
  _TutorialStep(
    icon: Icons.insights_rounded,
    color: AppTheme.brandViolet,
    title: 'Track progress, tune the experience',
    body:
        'The Progress tab celebrates streaks, points, and completed '
        'lessons. In Settings, you can adjust fonts, contrast, sound, and '
        'language — and you can always replay this tutorial anytime.',
    audioUrl: '$_kTutorialAssetBase/progress-settings.wav',
  ),
];

/// Narrated, first-run onboarding walkthrough. Shown automatically the first
/// time an account signs in (see the router's redirect logic) and always
/// reachable again from Settings.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _pageController = PageController();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _voice = AudioPlayer();
  int _page = 0;
  bool _narrating = false;

  @override
  void dispose() {
    _pageController.dispose();
    _tts.stop();
    _voice.dispose();
    super.dispose();
  }

  Future<void> _listen(_TutorialStep step) async {
    _tts.stop();
    unawaited(_voice.stop().timeout(const Duration(seconds: 2), onTimeout: () {}));
    setState(() => _narrating = true);
    try {
      await _voice.play(UrlSource(step.audioUrl));
    } catch (_) {
      _tts.speak(step.body);
    } finally {
      if (mounted) setState(() => _narrating = false);
    }
  }

  Future<void> _markSeenAndLeave() async {
    _tts.stop();
    _voice.stop();
    final uid = ref.read(authStateProvider).value?.id;
    if (uid != null) {
      await ref
          .read(sharedPreferencesProvider)
          .setBool('has_seen_tutorial_$uid', true);
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _next() {
    if (_page == _tutorialSteps.length - 1) {
      _markSeenAndLeave();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_page == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _tutorialSteps.length - 1;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.heroGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _markSeenAndLeave,
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _tutorialSteps.length,
                      onPageChanged: (index) {
                        _tts.stop();
                        _voice.stop();
                        setState(() {
                          _page = index;
                          _narrating = false;
                        });
                      },
                      itemBuilder: (context, index) =>
                          _TutorialStepView(
                            step: _tutorialSteps[index],
                            isNarrating: _narrating,
                            onListen: () => _listen(_tutorialSteps[index]),
                          ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _tutorialSteps.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                child: Row(
                  children: [
                    if (_page > 0)
                      TextButton(
                        onPressed: _back,
                        child: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.brandViolet,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                      ),
                      child: Text(isLast ? 'Get started' : 'Next'),
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
}

class _TutorialStepView extends StatelessWidget {
  const _TutorialStepView({
    required this.step,
    required this.isNarrating,
    required this.onListen,
  });

  final _TutorialStep step;
  final bool isNarrating;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, size: 46, color: Colors.white),
          ),
          const SizedBox(height: 28),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 15.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: isNarrating ? null : onListen,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            ),
            icon: isNarrating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.volume_up_rounded),
            label: const Text('Listen'),
          ),
        ],
      ),
    );
  }
}
