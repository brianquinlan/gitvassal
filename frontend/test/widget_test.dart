import 'package:flutter_test/flutter_test.dart';
import 'package:task_vassal/models/task_model.dart';
import 'package:task_vassal/models/user_settings_model.dart';
import 'package:task_vassal/state/app_state.dart';

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
      expect(task.isHighPriority, isTrue);
      expect(task.isPr, isFalse);
      expect(task.inferredBadge, equals('bug'));
      expect(task.formattedTimeAgo, equals('2 days ago'));
      expect(task.subtitleInfo, contains('#100'));
      expect(task.subtitleInfo, contains('by google'));

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

    test('TaskModel inferred badges work for various issue types', () {
      final docTask = TaskModel(
        id: '1',
        priority: 0.3,
        priorityNeedsUpdated: false,
        githubIssueTitle: 'Update routing documentation',
      );
      expect(docTask.inferredBadge, equals('docs'));

      final featTask = TaskModel(
        id: '2',
        priority: 0.5,
        priorityNeedsUpdated: false,
        githubIssueTitle: 'Add support for HTTP/3 client',
      );
      expect(featTask.inferredBadge, equals('enhancement'));
    });
  });

  group('UserSettingsModel Tests', () {
    test('UserSettingsModel maps to Firestore dictionary format', () {
      final settings = UserSettingsModel(
        uid: 'user123',
        githubAccessToken: 'ghp_test123456789',
        githubUsername: 'octocat',
        geminiApiKey: 'AIzaSyTestKey',
        monitoredRepos: ['google/flutter', 'dart-lang/http'],
      );

      final map = settings.toFirestoreMap();
      expect(map['github_access_token'], equals('ghp_test123456789'));
      expect(map['github_username'], equals('octocat'));
      expect(map['gemini_api_key'], equals('AIzaSyTestKey'));
      expect(map['monitored_repos'], isA<Map>());
      expect((map['monitored_repos'] as Map).containsKey('google/flutter'), isTrue);
      expect((map['monitored_repos'] as Map).containsKey('dart-lang/http'), isTrue);
    });
  });

  group('AppState Tests', () {
    test('AppState filtering by category and search query', () {
      final state = AppState();

      final tasks = [
        TaskModel(
          id: '1',
          priority: 0.9,
          priorityNeedsUpdated: false,
          owner: 'dart-lang',
          repo: 'http',
          issueNumber: 1024,
          githubIssueTitle: 'Support for HTTP/3 in underlying client',
          sources: ['assigned', 'monitored'],
        ),
        TaskModel(
          id: '2',
          priority: 0.8,
          priorityNeedsUpdated: false,
          owner: 'google',
          repo: 'flutter',
          issueNumber: 45892,
          githubIssueTitle: 'Add support for generic types in navigation',
          sources: ['created', 'monitored'],
        ),
        TaskModel(
          id: '3',
          priority: 0.7,
          priorityNeedsUpdated: false,
          owner: 'facebook',
          repo: 'react',
          issueNumber: 2451,
          githubIssueTitle: 'Memory leak in useEffect cleanup cycle',
          sources: ['mentioned'],
        ),
      ];

      // All tasks
      expect(state.filterTasks(tasks).length, equals(3));

      // Filter by assigned
      state.setSelectedCategory(FilterCategory.assigned);
      final assigned = state.filterTasks(tasks);
      expect(assigned.length, equals(1));
      expect(assigned.first.repo, equals('http'));

      // Filter by created
      state.setSelectedCategory(FilterCategory.created);
      final created = state.filterTasks(tasks);
      expect(created.length, equals(1));
      expect(created.first.repo, equals('flutter'));

      // Search query
      state.setSelectedCategory(FilterCategory.all);
      state.setSearchQuery('react');
      final searchResult = state.filterTasks(tasks);
      expect(searchResult.length, equals(1));
      expect(searchResult.first.owner, equals('facebook'));

      state.setSearchQuery('HTTP/3');
      expect(state.filterTasks(tasks).length, equals(1));
    });
  });
}
