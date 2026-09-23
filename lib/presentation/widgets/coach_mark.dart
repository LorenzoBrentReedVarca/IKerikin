import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../application/tutorial.dart';
import '../../core/theme/app_theme.dart';
import 'common_widgets.dart';

/// Marks a widget as spotlightable by the guided tour.
///
/// Registers a stable key under [id] so a tour step naming that id can measure
/// where the widget ended up, wherever it lives in the tree. Wrapping is
/// invisible and costs nothing when the tour is not running.
class CoachMarkTarget extends ConsumerWidget {
  const CoachMarkTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.read(tutorialControllerProvider.notifier).keyFor(id);
    return KeyedSubtree(key: key, child: child);
  }
}

/// Full-screen tour layer: dims the app, cuts a hole around the step's target,
/// and explains it in a card placed clear of the hole.
///
/// Sits above the whole screen rather than inside it, so it can spotlight the
/// bottom navigation as readily as anything in the body.
class CoachMarkOverlay extends ConsumerStatefulWidget {
  const CoachMarkOverlay({super.key, required this.onRequestBranch});

  /// Asks the shell to show a given branch, so a step can point at a widget on
  /// a tab the parent is not currently looking at.
  final ValueChanged<int> onRequestBranch;

  @override
  ConsumerState<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends ConsumerState<CoachMarkOverlay> {
  final _overlayKey = GlobalKey();
  final AudioPlayer _voice = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  Rect? _hole;
  int? _measuredFor;
  bool _narrating = false;

  @override
  void dispose() {
    _tts.stop();
    _voice.dispose();
    super.dispose();
  }

  /// Re-measures the current target after layout.
  ///
  /// Runs after every frame while the tour is up: switching branches and the
  /// dock's own selection animation both move things, and re-measuring is the
  /// simplest way to stay pinned to the target without guessing how long each
  /// settles. Only a changed rect triggers a rebuild, so this stays quiet once
  /// the step has settled.
  void _measure(TutorialState tour) {
    final targetKey = ref
        .read(tutorialControllerProvider.notifier)
        .targetKey(tour.step.targetId);
    final targetBox = targetKey?.currentContext?.findRenderObject();
    final overlayBox = _overlayKey.currentContext?.findRenderObject();

    Rect? rect;
    if (targetBox is RenderBox &&
        overlayBox is RenderBox &&
        targetBox.hasSize &&
        overlayBox.hasSize) {
      final topLeft = targetBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
      rect = topLeft & targetBox.size;
    }

    if (rect != _hole || _measuredFor != tour.index) {
      setState(() {
        _hole = rect;
        _measuredFor = tour.index;
      });
    }
  }

  Future<void> _listen(TutorialStep step) async {
    _tts.stop();
    // Fire-and-forget with a timeout: on Flutter web, stopping a player that
    // has never played anything can hang instead of resolving.
    unawaited(
      _voice.stop().timeout(const Duration(seconds: 2), onTimeout: () {}),
    );
    setState(() => _narrating = true);
    try {
      await _voice.play(UrlSource(audioUrlFor(step)));
    } catch (_) {
      // No pre-rendered narration for this step (or no network) — the
      // on-device voice still reads it out. See tool/seed_tutorial_narration.
      _tts.speak(step.body);
    } finally {
      if (mounted) setState(() => _narrating = false);
    }
  }

  void _stopAudio() {
    _tts.stop();
    _voice.stop();
  }

  @override
  Widget build(BuildContext context) {
    final tour = ref.watch(tutorialControllerProvider);
    if (!tour.active) return const SizedBox.shrink();

    final controller = ref.read(tutorialControllerProvider.notifier);
    final step = tour.step;

    // Bring the right tab forward before the target is measured.
    final branch = step.branchIndex;
    if (branch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRequestBranch(branch);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure(tour);
    });

    final hole = _measuredFor == tour.index ? _hole : null;
    final padded = hole?.inflate(step.shape == CoachMarkShape.circle ? 6 : 8);

    return Material(
      key: _overlayKey,
      type: MaterialType.transparency,
      child: Semantics(
        container: true,
        label: 'App tour, step ${tour.index + 1} of ${tutorialSteps.length}',
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _stopAudio();
                  controller.next();
                },
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    hole: padded,
                    circular: step.shape == CoachMarkShape.circle,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: _CoachCard(
                step: step,
                hole: padded,
                index: tour.index,
                total: tutorialSteps.length,
                isFirst: tour.isFirst,
                isLast: tour.isLast,
                narrating: _narrating,
                onListen: () => _listen(step),
                onNext: () {
                  _stopAudio();
                  controller.next();
                },
                onBack: () {
                  _stopAudio();
                  controller.back();
                },
                onSkip: () {
                  _stopAudio();
                  controller.finish();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dims everything except the spotlit target, which keeps its own colours and
/// gains a soft ring so it reads as the thing being talked about.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.hole, required this.circular});

  final Rect? hole;
  final bool circular;

  static const _scrim = Color(0xE6120B1F);

  Path _holePath(Rect rect) {
    if (circular) {
      return Path()..addOval(
        Rect.fromCircle(
          center: rect.center,
          radius: rect.longestSide / 2,
        ),
      );
    }
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final rect = hole;
    if (rect == null) {
      canvas.drawRect(full, Paint()..color = _scrim);
      return;
    }
    final cut = _holePath(rect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(full), cut),
      Paint()..color = _scrim,
    );
    canvas.drawPath(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: .92),
    );
    canvas.drawPath(
      cut,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppTheme.brandViolet.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.hole != hole || old.circular != circular;
}

/// The explanation card, placed on whichever side of the hole has more room.
class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.step,
    required this.hole,
    required this.index,
    required this.total,
    required this.isFirst,
    required this.isLast,
    required this.narrating,
    required this.onListen,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TutorialStep step;
  final Rect? hole;
  final int index;
  final int total;
  final bool isFirst;
  final bool isLast;
  final bool narrating;
  final VoidCallback onListen;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final card = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: _cardBody(context),
    );

    // No target (the opening and closing steps): centre the card.
    if (hole == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: card),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sit on whichever side of the spotlight has more room, so the card
        // never covers the thing it is pointing at.
        final height = constraints.maxHeight;
        final above = hole!.top - padding.top;
        final below = height - hole!.bottom - padding.bottom;
        final placeBelow = below >= above;
        // The Positioned needs a Stack of its own: this widget is handed a
        // full-bleed slot, and LayoutBuilder in between is not a Stack.
        return Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: placeBelow ? hole!.bottom + 18 : null,
              bottom: placeBelow ? null : height - hole!.top + 18,
              // Shrink-wrap vertically: only one edge is pinned, so the slot
              // is unbounded in height and the card must size to its content.
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1,
                child: card,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cardBody(BuildContext context) {
    final reduced = prefersReducedMotion(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(index),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .34),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${index + 1}/$total',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: narrating ? null : onListen,
                  icon: narrating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Listen'),
                ),
                const Spacer(),
                if (!isFirst)
                  TextButton(onPressed: onBack, child: const Text('Back')),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: onNext,
                  child: Text(isLast ? 'Finish' : 'Next'),
                ),
              ],
            ),
            if (!isLast)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip the tour'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
