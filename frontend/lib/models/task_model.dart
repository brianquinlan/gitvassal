import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a prioritized GitHub task associated with an authenticated user.
class TaskModel {
  final String id;
  final double priority;
  final bool priorityNeedsUpdated;
  final bool isPr;
  final String? owner;
  final String? repo;
  final int? issueNumber;
  final String? githubIssueTitle;
  final String? githubIssueUrl;
  final List<String> sources;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    required this.id,
    required this.priority,
    required this.priorityNeedsUpdated,
    this.isPr = false,
    this.owner,
    this.repo,
    this.issueNumber,
    this.githubIssueTitle,
    this.githubIssueUrl,
    this.sources = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to parse a Firestore document snapshot into [TaskModel].
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    double parsePriority(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    List<String> parseSources(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    return TaskModel(
      id: doc.id,
      priority: parsePriority(data['priority']),
      priorityNeedsUpdated: data['priority_needs_updated'] == true,
      isPr: data['is_pr'] == true,
      owner: data['owner']?.toString(),
      repo: data['repo']?.toString(),
      issueNumber: data['issue_number'] is int
          ? data['issue_number'] as int
          : int.tryParse(data['issue_number']?.toString() ?? ''),
      githubIssueTitle: data['github_issue_title']?.toString(),
      githubIssueUrl: data['github_issue_url']?.toString(),
      sources: parseSources(data['sources']),
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  /// Full repository identifier, e.g. "dart-lang/http".
  String get repoFullName {
    if (owner != null && repo != null) {
      return '$owner/$repo';
    }
    return repo ?? owner ?? 'unknown/repo';
  }

  /// Display title for the issue.
  String get displayTitle {
    if (githubIssueTitle != null && githubIssueTitle!.isNotEmpty) {
      return githubIssueTitle!;
    }
    if (issueNumber != null) {
      return 'Issue #$issueNumber';
    }
    return 'GitHub Issue';
  }

  Map<String, dynamic> toMap() {
    return {
      'priority': priority,
      'priority_needs_updated': priorityNeedsUpdated,
      'is_pr': isPr,
      'owner': owner,
      'repo': repo,
      'issue_number': issueNumber,
      'github_issue_title': githubIssueTitle,
      'github_issue_url': githubIssueUrl,
      'sources': sources,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
