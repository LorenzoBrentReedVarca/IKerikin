import 'package:flutter_test/flutter_test.dart';
import 'package:ikerikin/domain/models.dart';

void main() {
  test('child age is derived from birthday', () {
    final now = DateTime.now();
    final child = ChildProfile(
      id: 'child',
      parentId: 'parent',
      name: 'Learner',
      birthday: DateTime(now.year - 8, now.month, now.day),
      gender: 'Prefer not to say',
      preferredLanguage: 'English',
      disabilities: const [],
      challenges: const [],
      interests: const ['Animals'],
      learningStyles: const ['Mixed'],
    );
    expect(child.age, 8);
  });
}
