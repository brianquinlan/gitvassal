import 'package:cloud_firestore/cloud_firestore.dart';
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

    test('TaskModel handles thumbsDownAt serialization correctly', () {
      final downTime = DateTime.utc(2026, 9, 4, 12, 30);
      final task = TaskModel(
        id: 'task_deprioritized_1',
        priority: 0.0,
        priorityNeedsUpdated: false,
        thumbsDownAt: downTime,
      );

      expect(task.priority, equals(0.0));
      expect(task.thumbsDownAt, equals(downTime));

      final map = task.toMap();
      expect(map['priority'], equals(0.0));
      expect(map['thumbs_down_at'], isNotNull);
    });

    test('TaskModel.fromFirestore standardizes parsed dates to UTC', () {
      final fakeDoc = FakeDocumentSnapshot('task_123', {
        'priority': 0.75,
        'priority_needs_updated': false,
        'created_at': '2026-09-05T12:00:00Z',
        'updated_at': '2026-09-05T08:00:00-04:00',
        'thumbs_down_at': 1788612000000, // milliseconds epoch
      });

      final task = TaskModel.fromFirestore(fakeDoc);
      expect(task.createdAt?.isUtc, isTrue);
      expect(task.updatedAt?.isUtc, isTrue);
      expect(task.thumbsDownAt?.isUtc, isTrue);
      expect(task.createdAt, equals(DateTime.utc(2026, 9, 5, 12, 0, 0)));
      expect(task.updatedAt, equals(DateTime.utc(2026, 9, 5, 12, 0, 0)));
    });
  });

  group('UserSettingsModel Tests', () {
    test('UserSettingsModel maps to Firestore dictionary format', () {
      final syncTime = DateTime.utc(2026, 8, 20, 10, 0);
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

    test('UserSettingsModel.fromFirestore standardizes monitored_repos to UTC', () {
      final fakeDoc = FakeDocumentSnapshot('user123', {
        'monitored_repos': {
          'dart-lang/http': '2026-09-05T12:00:00Z',
        },
        'updated_at': '2026-09-05T16:00:00Z',
      });

      final settings = UserSettingsModel.fromFirestore(fakeDoc);
      expect(settings.updatedAt?.isUtc, isTrue);
      expect(settings.monitoredRepos['dart-lang/http']?.isUtc, isTrue);
      expect(settings.monitoredRepos['dart-lang/http'], equals(DateTime.utc(2026, 9, 5, 12, 0, 0)));
    });
  });
}

// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  final String id;
  final Map<String, dynamic>? _data;

  FakeDocumentSnapshot(this.id, this._data);

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
