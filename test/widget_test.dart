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

  test('VideoScene round-trips through json', () {
    final scene = VideoScene(
      sceneNumber: 1,
      durationSeconds: 8,
      narration: 'Once upon a time',
      visualPrompt: 'A friendly dog learns to share',
      educationalObjective: 'Practice sharing',
    );
    final restored = VideoScene.fromJson(scene.toJson());
    expect(restored.sceneNumber, scene.sceneNumber);
    expect(restored.durationSeconds, scene.durationSeconds);
    expect(restored.narration, scene.narration);
    expect(restored.visualPrompt, scene.visualPrompt);
    expect(restored.educationalObjective, scene.educationalObjective);
  });

  test('parseVideoGenerationStatus maps known values', () {
    expect(
      parseVideoGenerationStatus('completed'),
      VideoGenerationStatus.completed,
    );
    expect(parseVideoGenerationStatus('failed'), VideoGenerationStatus.failed);
    expect(
      parseVideoGenerationStatus('unknown'),
      VideoGenerationStatus.queued,
    );
    expect(parseVideoGenerationStatus(null), VideoGenerationStatus.queued);
  });

  test('GeneratedVideoScene parses snake_case database json', () {
    final scene = GeneratedVideoScene.fromJson({
      'id': 'scene-1',
      'job_id': 'job-1',
      'lesson_id': 'lesson-1',
      'child_id': 'child-1',
      'scene_number': 2,
      'provider': 'runway',
      'generation_status': 'processing',
      'generation_job_id': 'provider-job-1',
      'video_url': null,
      'error_message': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    });
    expect(scene.sceneNumber, 2);
    expect(scene.status, VideoGenerationStatus.processing);
    expect(scene.providerJobId, 'provider-job-1');
  });

  test('VideoGenerationJob exposes isComplete/isFailed correctly', () {
    final completed = VideoGenerationJob.fromJson({
      'id': 'job-1',
      'lesson_id': 'lesson-1',
      'child_id': 'child-1',
      'provider': 'runway',
      'status': 'completed',
      'video_url': null,
      'error_message': null,
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    });
    expect(completed.isComplete, true);
    expect(completed.isFailed, false);

    final failed = VideoGenerationJob.fromJson({
      'id': 'job-2',
      'lesson_id': 'lesson-1',
      'child_id': 'child-1',
      'provider': 'runway',
      'status': 'failed',
      'video_url': null,
      'error_message': 'boom',
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    });
    expect(failed.isFailed, true);
    expect(failed.isComplete, false);
  });
}
