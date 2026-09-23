import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikerikin/application/providers.dart';
import 'package:ikerikin/application/tutorial.dart';
import 'package:ikerikin/domain/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ids the app actually registers a `CoachMarkTarget` for. A step naming
/// anything else still renders — as a centered card with no spotlight — so a
/// typo here would quietly downgrade the tour rather than fail. Kept beside
/// the dock's own `tourId`s in app_shell.dart and the settings button in
/// learning_screens.dart.
const _registeredTargets = {
  'nav-home',
  'nav-lessons',
  'nav-create',
  'nav-progress',
  'nav-profile',
  'home-settings',
};

ProviderContainer _container(SharedPreferences prefs) => ProviderContainer(
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

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('tour script', () {
    test('every spotlight points at a target the app registers', () {
      for (final step in tutorialSteps) {
        if (step.targetId == null) continue;
        expect(
          _registeredTargets,
          contains(step.targetId),
          reason: '"${step.title}" spotlights an unregistered target',
        );
      }
    });

    test('a step with a target names the branch it lives on', () {
      for (final step in tutorialSteps) {
        if (step.targetId == null) continue;
        expect(
          step.branchIndex,
          isNotNull,
          reason: '"${step.title}" would measure whatever tab happens to be up',
        );
        expect(step.branchIndex, inInclusiveRange(0, 4));
      }
    });

    test('narration slugs are unique, so no step overwrites another', () {
      final slugs = tutorialSteps.map((step) => step.audioSlug).toList();
      expect(slugs.toSet(), hasLength(slugs.length));
    });

    test('opens and closes on a centered card', () {
      expect(tutorialSteps.first.targetId, isNull);
      expect(tutorialSteps.last.targetId, isNull);
    });

    test('narration path is relative to the bucket, not a fixed host', () {
      expect(tutorialNarrationPath('welcome'), 'tutorial/welcome.wav');
      expect(tutorialNarrationPath('welcome'), isNot(contains('http')));
      expect(tutorialNarrationPath('welcome'), isNot(contains('supabase')));
    });
  });

  group('TutorialController', () {
    test('starts inactive and begins at the first step', () {
      final container = _container(prefs);
      addTearDown(container.dispose);

      expect(container.read(tutorialControllerProvider).active, isFalse);
      container.read(tutorialControllerProvider.notifier).start();

      final state = container.read(tutorialControllerProvider);
      expect(state.active, isTrue);
      expect(state.index, 0);
      expect(state.isFirst, isTrue);
    });

    test('advances and rewinds, clamping at the first step', () {
      final container = _container(prefs);
      addTearDown(container.dispose);
      final tour = container.read(tutorialControllerProvider.notifier);

      tour.start();
      tour.next();
      tour.next();
      expect(container.read(tutorialControllerProvider).index, 2);

      tour.back();
      expect(container.read(tutorialControllerProvider).index, 1);

      tour.back();
      tour.back();
      expect(
        container.read(tutorialControllerProvider).index,
        0,
        reason: 'Back on the first step should stay put, not go negative',
      );
    });

    test('finishing past the last step ends the tour', () {
      final container = _container(prefs);
      addTearDown(container.dispose);
      final tour = container.read(tutorialControllerProvider.notifier);

      tour.start();
      for (var i = 0; i < tutorialSteps.length - 1; i++) {
        tour.next();
      }
      expect(container.read(tutorialControllerProvider).isLast, isTrue);

      tour.next();
      expect(container.read(tutorialControllerProvider).active, isFalse);
    });

    test('remembers it was seen, so first run does not fire twice', () async {
      final container = _container(prefs);
      addTearDown(container.dispose);
      // The controller reads the signed-in user synchronously, so let the
      // overridden stream deliver its value before asking.
      final sub = container.listen(authStateProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final tour = container.read(tutorialControllerProvider.notifier);

      expect(prefs.getBool(TutorialController.seenKey('user-1')), isNull);
      tour.start();
      await tour.finish();

      expect(container.read(tutorialControllerProvider).active, isFalse);
      expect(prefs.getBool(TutorialController.seenKey('user-1')), isTrue);

      // A later launch must not offer it again.
      expect(tour.startIfUnseen(), isTrue);
      expect(container.read(tutorialControllerProvider).active, isFalse);
    });

    test('defers the first-run decision until the user is known', () async {
      // The router lets the shell mount while auth is still loading, so the
      // check can run before the signed-in user arrives. It must report that
      // it could not decide rather than quietly declining to start, or the
      // tour is skipped for good — the shell mounts only once per launch.
      final auth = StreamController<AppUser?>();
      addTearDown(auth.close);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => auth.stream),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(authStateProvider, (_, _) {});
      addTearDown(sub.close);
      final tour = container.read(tutorialControllerProvider.notifier);

      expect(
        tour.startIfUnseen(),
        isFalse,
        reason: 'the user is not known yet, so nothing can be decided',
      );
      expect(container.read(tutorialControllerProvider).active, isFalse);

      auth.add(const AppUser(
        id: 'user-1',
        email: 'parent@example.com',
        displayName: 'Parent',
        role: UserRole.parent,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(
        tour.startIfUnseen(),
        isTrue,
        reason: 'the user is known now, so the check can settle',
      );
      expect(
        container.read(tutorialControllerProvider).active,
        isTrue,
        reason: 'a first-run account should get the tour once auth resolves',
      );
    });

    test('does not restart the tour for an account that has seen it', () async {
      await prefs.setBool(TutorialController.seenKey('user-1'), true);
      final container = _container(prefs);
      addTearDown(container.dispose);
      final sub = container.listen(authStateProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      final tour = container.read(tutorialControllerProvider.notifier);
      expect(tour.startIfUnseen(), isTrue, reason: 'the user is known');
      expect(container.read(tutorialControllerProvider).active, isFalse);
    });

    test('registers one stable key per target id', () {
      final container = _container(prefs);
      addTearDown(container.dispose);
      final tour = container.read(tutorialControllerProvider.notifier);

      final first = tour.keyFor('nav-home');
      expect(
        tour.keyFor('nav-home'),
        same(first),
        reason: 'A new key each build would detach the widget every frame',
      );
      expect(tour.keyFor('nav-lessons'), isNot(same(first)));
      expect(tour.targetKey('nav-home'), same(first));
      expect(tour.targetKey('never-registered'), isNull);
      expect(tour.targetKey(null), isNull);
    });
  });
}
