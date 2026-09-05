import 'package:flutter_test/flutter_test.dart';
import 'package:task_vassal/models/task_model.dart';
import 'package:task_vassal/models/user_settings_model.dart';

void main() {
  group('TaskModel Tests', () {
    test('TaskModel getters and helpers work correctly', () {
      final task = TaskModel(
        id: 'task_google_flutter_100',
        priority: 0.85,
        priorityNeedsUpdated: false,
        isPr: false,
        owner: 'google',
        repo: 'flutter',
        issueNumber: 100,
        githubIssueTitle: 'Fix memory leak in engine',
        githubIssueUrl: 'https://github.com/google/flutter/issues/100',
        sources: ['assigned', 'monitored'],
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(task.repoFullName, equals('google/flutter'));
      expect(task.displayTitle, equals('Fix memory leak in engine'));
      expect(task.isPr, isFalse);

      final map = task.toMap();
      expect(map['owner'], equals('google'));
      expect(map['repo'], equals('flutter'));
      expect(map['priority'], equals(0.85));
      expect(map['is_pr'], isFalse);
    });

    test('TaskModel distinguishes Pull Requests from Issues using is_pr', () {
      final prTask = TaskModel(
        id: 'pr_1',
        priority: 0.5,
        priorityNeedsUpdated: false,
        isPr: true,
        githubIssueTitle: 'Add HTTP/3 client support',
        githubIssueUrl: 'https://github.com/dart-lang/http/pull/1024',
      );
      expect(prTask.isPr, isTrue);

      final issueTask = TaskModel(
        id: 'issue_1',
        priority: 0.5,
        priorityNeedsUpdated: false,
        isPr: false,
        githubIssueTitle: 'Bug in HTTP/3 client',
        githubIssueUrl: 'https://github.com/dart-lang/http/issues/1024',
      );
      expect(issueTask.isPr, isFalse);
    });
  });

  group('UserSettingsModel Tests', () {
    test('UserSettingsModel maps to Firestore dictionary format', () {
      final syncTime = DateTime(2026, 8, 20, 10, 0);
      final settings = UserSettingsModel(
        uid: 'user123',
        githubAccessToken: 'ghp_test123456789',
        githubUsername: 'octocat',
        geminiApiKey: 'AIzaSyTestKey',
        monitoredRepos: {
          'google/flutter': syncTime,
          'dart-lang/http': null,
        },
      );

      expect(settings.monitoredRepoNames, containsAll(['google/flutter', 'dart-lang/http']));

      final map = settings.toFirestoreMap();
      expect(map['github_access_token'], equals('ghp_test123456789'));
      expect(map['github_username'], equals('octocat'));
      expect(map['gemini_api_key'], equals('AIzaSyTestKey'));
      expect(map['monitored_repos'], isA<Map>());
      final repos = map['monitored_repos'] as Map<String, DateTime?>;
      expect(repos['google/flutter'], equals(syncTime));
      expect(repos['dart-lang/http'], isNull);
    });
  });
}
