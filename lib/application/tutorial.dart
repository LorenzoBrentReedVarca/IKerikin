import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import 'providers.dart';
import 'tutorial_script.dart';

export 'tutorial_script.dart';

/// Where a step's pre-rendered narration lives.
///
/// Derived from the configured Supabase project rather than written out, so a
/// `--dart-define=SUPABASE_URL=...` build points at its own storage instead of
/// whatever project happened to be current when this was written. Missing
/// audio is not fatal — the overlay falls back to the on-device voice — so a
/// project whose bucket has not been seeded still narrates.
String audioUrlFor(TutorialStep step) => AppConfig.supabase.storage
    .from(tutorialNarrationBucket)
    .getPublicUrl(tutorialNarrationPath(step.audioSlug));

/// Whether the tour is running, and where it has got to.
@immutable
class TutorialState {
  const TutorialState({this.active = false, this.index = 0});

  final bool active;
  final int index;

  TutorialStep get step => tutorialSteps[index];
  bool get isFirst => index == 0;
  bool get isLast => index == tutorialSteps.length - 1;

  TutorialState copyWith({bool? active, int? index}) =>
      TutorialState(active: active ?? this.active, index: index ?? this.index);
}

/// Drives the guided tour and holds the registry of spotlightable widgets.
///
/// Targets register themselves by id as they build, so the controller can hand
/// the overlay a [GlobalKey] to measure without the overlay needing to know
/// which screen the widget lives on.
class TutorialController extends Notifier<TutorialState> {
  final _targets = <String, GlobalKey>{};

  /// Per-account, per-device flag. A parent who signs in on a new phone gets
  /// the tour again there, which is the intent — it teaches this device's
  /// screen, not the account.
  static String seenKey(String userId) => 'has_seen_tutorial_$userId';

  @override
  TutorialState build() => const TutorialState();

  /// Stable key for a spotlightable widget. Called from `CoachMarkTarget`
  /// during build, so it must return the same key for the same id every time.
  GlobalKey keyFor(String id) => _targets.putIfAbsent(id, () => GlobalKey());

  /// The target's key, if a widget with that id has ever registered.
  GlobalKey? targetKey(String? id) => id == null ? null : _targets[id];

  void start() => state = const TutorialState(active: true);

  void next() {
    if (state.isLast) {
      finish();
      return;
    }
    state = state.copyWith(index: state.index + 1);
  }

  void back() {
    if (state.isFirst) return;
    state = state.copyWith(index: state.index - 1);
  }

  /// Ends the tour and remembers it was seen, so the first-run check does not
  /// fire again on this device.
  Future<void> finish() async {
    state = const TutorialState();
    final userId = ref.read(authStateProvider).value?.id;
    if (userId == null) return;
    await ref.read(sharedPreferencesProvider).setBool(seenKey(userId), true);
  }

  /// Whether this account still needs the first-run tour on this device.
  bool get isUnseen {
    final userId = ref.read(authStateProvider).value?.id;
    if (userId == null) return false;
    return ref.read(sharedPreferencesProvider).getBool(seenKey(userId)) != true;
  }
}

final tutorialControllerProvider =
    NotifierProvider<TutorialController, TutorialState>(
      TutorialController.new,
    );
