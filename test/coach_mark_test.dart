import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikerikin/application/providers.dart';
import 'package:ikerikin/application/tutorial.dart';
import 'package:ikerikin/domain/models.dart';
import 'package:ikerikin/presentation/widgets/coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the real shell: a body and a bottom bar carrying the same
/// target ids the dock registers, so the overlay has something real to
/// measure without needing a StatefulNavigationShell.
class _FakeShell extends StatelessWidget {
  const _FakeShell({required this.branch, required this.onRequestBranch});

  final int branch;
  final ValueChanged<int> onRequestBranch;

  static const _tabs = [
    'nav-home',
    'nav-lessons',
    'nav-create',
    'nav-progress',
    'nav-profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            actions: [
              if (branch == 0)
                const CoachMarkTarget(
                  id: 'home-settings',
                  child: Icon(Icons.settings_outlined),
                ),
            ],
          ),
          body: Center(child: Text('branch $branch')),
          bottomNavigationBar: SizedBox(
            height: 74,
            child: Row(
              children: [
                for (final id in _tabs)
                  Expanded(
                    child: CoachMarkTarget(id: id, child: Center(child: Text(id))),
                  ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: CoachMarkOverlay(onRequestBranch: onRequestBranch),
        ),
      ],
    );
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> pumpTour(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream<AppUser?>.value(
            const AppUser(
              id: 'user-1',
              email: 'parent@example.com',
              displayName: 'Parent',
              role: UserRole.parent,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    var branch = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => _FakeShell(
              branch: branch,
              onRequestBranch: (next) {
                if (next != branch) setState(() => branch = next);
              },
            ),
          ),
        ),
      ),
    );
    return container;
  }

  testWidgets('stays out of the way until the tour starts', (tester) async {
    final container = await pumpTour(tester);

    expect(find.text(tutorialSteps.first.title), findsNothing);

    container.read(tutorialControllerProvider.notifier).start();
    await tester.pumpAndSettle();

    expect(find.text(tutorialSteps.first.title), findsOneWidget);
  });

  testWidgets('walks every step and lands on Finish', (tester) async {
    final container = await pumpTour(tester);
    container.read(tutorialControllerProvider.notifier).start();
    await tester.pumpAndSettle();

    for (var i = 0; i < tutorialSteps.length; i++) {
      expect(
        find.text(tutorialSteps[i].title),
        findsOneWidget,
        reason: 'step $i should be showing',
      );
      expect(find.text('${i + 1}/${tutorialSteps.length}'), findsOneWidget);
      if (i < tutorialSteps.length - 1) {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
        await tester.pumpAndSettle();
      }
    }

    expect(find.widgetWithText(ElevatedButton, 'Finish'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Finish'));
    await tester.pumpAndSettle();

    expect(container.read(tutorialControllerProvider).active, isFalse);
    expect(find.text(tutorialSteps.last.title), findsNothing);
  });

  testWidgets('spotlights the real dock item, not a centered card', (
    tester,
  ) async {
    final container = await pumpTour(tester);
    final tour = container.read(tutorialControllerProvider.notifier);
    tour.start();
    await tester.pumpAndSettle();

    // Step 1 targets nav-home. The painter should have cut a hole that sits
    // over the real dock item rather than leaving the screen evenly dimmed.
    tour.next();
    await tester.pumpAndSettle();

    final step = container.read(tutorialControllerProvider).step;
    expect(step.targetId, 'nav-home');

    final targetRect = tester.getRect(find.text('nav-home'));
    // Material and Semantics contribute their own CustomPaints, so pick out
    // the spotlight's by its painter.
    final spotlights = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(CoachMarkOverlay),
            matching: find.byType(CustomPaint),
          ),
        )
        .where((paint) => '${paint.painter?.runtimeType}' == '_SpotlightPainter')
        .toList();
    expect(spotlights, hasLength(1));
    final hole = (spotlights.single.painter as dynamic).hole as Rect?;

    expect(hole, isNotNull, reason: 'the target should have been measured');
    expect(
      hole!.inflate(1).contains(targetRect.center),
      isTrue,
      reason: 'the spotlight should sit over the dock item it describes',
    );
  });

  testWidgets('skipping ends the tour and remembers it', (tester) async {
    final container = await pumpTour(tester);
    final sub = container.listen(authStateProvider, (_, _) {});
    addTearDown(sub.close);
    await tester.pump();

    container.read(tutorialControllerProvider.notifier).start();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip the tour'));
    await tester.pumpAndSettle();

    expect(container.read(tutorialControllerProvider).active, isFalse);
    expect(prefs.getBool(TutorialController.seenKey('user-1')), isTrue);
  });
}
