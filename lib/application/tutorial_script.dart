/// The guided tour's script and shape, with no Flutter dependency.
///
/// Kept free of imports on purpose: `tool/seed_tutorial_narration.dart` runs
/// under plain `dart run` and reads the steps from here, so the narration
/// audio is always rendered from the same words the app shows. Anything that
/// needs Flutter or Supabase lives in `tutorial.dart` instead.
library;

/// Cut-out shape used to spotlight a step's target.
enum CoachMarkShape { rounded, circle }

/// One stop on the guided tour.
///
/// A step either spotlights a real, on-screen widget — named by [targetId] and
/// registered by a `CoachMarkTarget` somewhere in the tree — or, when
/// [targetId] is null, presents a centered card over a plain dim (used to open
/// and close the tour).
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    required this.audioSlug,
    this.targetId,
    this.branchIndex,
    this.shape = CoachMarkShape.rounded,
  });

  final String title;
  final String body;

  /// Basename of the pre-rendered narration in `lesson-videos/tutorial/`.
  final String audioSlug;

  /// Registered target to spotlight, or null for a centered card.
  final String? targetId;

  /// Shell branch that must be showing for [targetId] to exist. The tour
  /// switches to it before measuring, so a step can point at a widget on a
  /// tab the parent is not currently looking at.
  final int? branchIndex;

  final CoachMarkShape shape;
}

/// Storage bucket holding the tutorial's narration audio. Shared, static app
/// content, so it sits under a fixed folder rather than a per-child path (see
/// migration 011 for the policies that allow it).
const tutorialNarrationBucket = 'lesson-videos';
const tutorialNarrationFolder = 'tutorial';

/// Object path of a step's narration within [tutorialNarrationBucket].
String tutorialNarrationPath(String audioSlug) =>
    '$tutorialNarrationFolder/$audioSlug.wav';

/// The guided tour, in order.
///
/// Every step that names a [TutorialStep.targetId] points at a widget that
/// really exists — the five dock stops and the settings button — so the tour
/// teaches the app as it is rather than describing a layout from memory.
const tutorialSteps = <TutorialStep>[
  TutorialStep(
    title: 'Welcome to IKeriKin',
    body:
        'IKeriKin means "I care for your kin." Every lesson here is built '
        'around your child — their interests, their pace, and the support '
        'they need. Let\'s walk through the app together.',
    audioSlug: 'welcome',
  ),
  TutorialStep(
    title: 'Home',
    body:
        'Home opens on today\'s learning path and picks up wherever your '
        'family left off. If you have more than one child, you can switch '
        'between them here.',
    audioSlug: 'home',
    targetId: 'nav-home',
    branchIndex: 0,
  ),
  TutorialStep(
    title: 'Lessons',
    body:
        'Everything already made for your child lives here, grouped by '
        'skill. A fresh lesson is added every day, chosen to suit your '
        'child\'s interests and the things they find harder.',
    audioSlug: 'lessons',
    targetId: 'nav-lessons',
    branchIndex: 1,
  ),
  TutorialStep(
    title: 'Create your own lesson',
    body:
        'Tap Create to build a lesson around any goal you choose — brushing '
        'teeth, sharing toys, naming feelings. IKeriKin writes the story, '
        'the games and the quiz for you.',
    audioSlug: 'create',
    targetId: 'nav-create',
    branchIndex: 2,
  ),
  TutorialStep(
    title: 'Inside every lesson',
    body:
        'Each lesson offers several ways to learn: an animated video, a calm '
        'story you can listen to together, flashcards, a quiz and matching '
        'games — plus tips written just for you.',
    audioSlug: 'inside-lesson',
    targetId: 'nav-lessons',
    branchIndex: 1,
  ),
  TutorialStep(
    title: 'Progress',
    body:
        'Progress celebrates streaks, points and finished lessons, so you '
        'can see how your child is doing without needing to keep score '
        'yourself.',
    audioSlug: 'progress',
    targetId: 'nav-progress',
    branchIndex: 3,
  ),
  TutorialStep(
    title: 'Your child\'s profile',
    body:
        'Profile holds your child\'s interests, and the disabilities and '
        'challenges you told us about. Keep it up to date — every new '
        'lesson is built from what it says.',
    audioSlug: 'profile',
    targetId: 'nav-profile',
    branchIndex: 4,
  ),
  TutorialStep(
    title: 'Settings and accessibility',
    body:
        'This button opens Settings, where you can adjust text size, '
        'contrast, sound and language — and replay this tour any time from '
        'the Help section.',
    audioSlug: 'settings',
    targetId: 'home-settings',
    branchIndex: 0,
    shape: CoachMarkShape.circle,
  ),
  TutorialStep(
    title: 'You\'re all set',
    body:
        'That\'s everything. If you ever want to see this again, it\'s under '
        'Settings, in the Help section. Enjoy learning together.',
    audioSlug: 'finish',
  ),
];
