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

    // Helper to safely parse DateTime from Timestamp, String, or int
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    // Helper to safely parse double priority
    double parsePriority(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    // Helper to parse sources
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

  /// Formatted metadata string e.g. "#1024 opened 2 days ago by jdoe".
  String get subtitleInfo {
    final numStr = issueNumber != null ? '#$issueNumber' : '';
    final timeStr = formattedTimeAgo;
    final ownerStr = owner != null ? 'by $owner' : '';

    final parts = [
      numStr,
      timeStr,
      ownerStr,
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(' ');
  }

  /// Friendly time ago string.
  String get formattedTimeAgo {
    final date = createdAt ?? updatedAt;
    if (date == null) return 'recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'just now';
    }
  }

  /// Primary label/category derived from sources or title.
  String get inferredBadge {
    final titleLower = (githubIssueTitle ?? '').toLowerCase();
    if (titleLower.contains('bug') ||
        titleLower.contains('fix') ||
        titleLower.contains('error') ||
        titleLower.contains('leak')) {
      return 'bug';
    }
    if (titleLower.contains('feat') ||
        titleLower.contains('support') ||
        titleLower.contains('add')) {
      return 'enhancement';
    }
    if (titleLower.contains('doc') || titleLower.contains('guide')) {
      return 'docs';
    }
    if (priority >= 0.7) {
      return 'high-priority';
    }
    if (sources.isNotEmpty) {
      return sources.first;
    }
    return 'issue';
  }

  /// Whether this task is considered high priority.
  bool get isHighPriority => priority >= 0.7;

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
