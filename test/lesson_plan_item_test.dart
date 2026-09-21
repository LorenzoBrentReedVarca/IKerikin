import 'package:flutter_test/flutter_test.dart';
import 'package:ikerikin/domain/models.dart';

/// `lesson_requests` CHECK-constrains difficulty and content_type and bounds
/// goal length. The planning prompt asks the model for valid values but
/// cannot bind it to them, and both callers swallow the resulting insert
/// error — so an unnormalized value surfaces only as the lesson shelf
/// quietly not growing. These lock the normalization in place.
void main() {
  group('LessonPlanItem.fromJson', () {
    test('passes valid values through untouched', () {
      final item = LessonPlanItem.fromJson({
        'goal': 'Learn to wash hands before eating',
        'difficulty': 'medium',
        'content_type': 'Cartoon Lesson',
      });
      expect(item.goal, 'Learn to wash hands before eating');
      expect(item.difficulty, LessonDifficulty.medium);
      expect(item.contentType, 'Cartoon Lesson');
      expect(item.isUsable, isTrue);
    });

    test('coerces an off-list content_type to Story', () {
      final item = LessonPlanItem.fromJson({
        'goal': 'Learn to say please and thank you',
        'difficulty': 'easy',
        'content_type': 'Adventure',
      });
      expect(ProfileOptions.contentTypes, contains(item.contentType));
      expect(item.contentType, 'Story');
    });

    test('coerces an off-list difficulty to easy', () {
      final item = LessonPlanItem.fromJson({
        'goal': 'Learn to recognize happy and sad',
        'difficulty': 'hard',
        'content_type': 'Story',
      });
      expect(item.difficulty, LessonDifficulty.easy);
    });

    test('defaults missing fields', () {
      final item = LessonPlanItem.fromJson({'goal': 'Learn to tie shoelaces'});
      expect(item.difficulty, LessonDifficulty.easy);
      expect(item.contentType, 'Story');
    });

    test('marks an empty or stub goal unusable', () {
      expect(LessonPlanItem.fromJson({'goal': ''}).isUsable, isFalse);
      expect(LessonPlanItem.fromJson({'goal': '   '}).isUsable, isFalse);
      expect(LessonPlanItem.fromJson({'goal': 'abc'}).isUsable, isFalse);
      expect(LessonPlanItem.fromJson(const {}).isUsable, isFalse);
    });

    test('truncates an overlong goal to the column bound', () {
      final item = LessonPlanItem.fromJson({'goal': 'x' * 900});
      expect(item.goal.length, 500);
      expect(item.goal, endsWith('…'));
      expect(item.isUsable, isTrue);
    });

    test('keeps a goal sitting exactly on the bound', () {
      final item = LessonPlanItem.fromJson({'goal': 'y' * 500});
      expect(item.goal.length, 500);
      expect(item.goal, isNot(contains('…')));
    });
  });
}
