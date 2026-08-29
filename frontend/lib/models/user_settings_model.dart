import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents user settings and profile metadata in Firestore under users/{uid}.
class UserSettingsModel {
  final String uid;
  final String? githubAccessToken;
  final String? githubUsername;
  final String? geminiApiKey;
  final List<String> monitoredRepos;
  final DateTime? updatedAt;

  UserSettingsModel({
    required this.uid,
    this.githubAccessToken,
    this.githubUsername,
    this.geminiApiKey,
    this.monitoredRepos = const [],
    this.updatedAt,
  });

  /// Factory constructor to parse a Firestore document snapshot.
  factory UserSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    // Parse monitored_repos which is stored as a Map or List in Firestore
    List<String> parseMonitoredRepos(dynamic val) {
      if (val is Map) {
        return val.keys.map((k) => k.toString().trim()).where((k) => k.isNotEmpty).toList();
      }
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return UserSettingsModel(
      uid: doc.id,
      githubAccessToken: data['github_access_token']?.toString(),
      githubUsername: data['github_username']?.toString(),
      geminiApiKey: data['gemini_api_key']?.toString(),
      monitoredRepos: parseMonitoredRepos(data['monitored_repos']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  /// Converts monitored repositories list into Firestore Map format { "owner/repo": null }
  Map<String, dynamic> toFirestoreMap() {
    final Map<String, dynamic> reposMap = {};
    for (final repo in monitoredRepos) {
      final clean = repo.trim();
      if (clean.isNotEmpty) {
        reposMap[clean] = null;
      }
    }

    return {
      'github_access_token': githubAccessToken?.trim().isEmpty ?? true ? null : githubAccessToken!.trim(),
      'github_username': githubUsername?.trim().isEmpty ?? true ? null : githubUsername!.trim(),
      'gemini_api_key': geminiApiKey?.trim().isEmpty ?? true ? null : geminiApiKey!.trim(),
      'monitored_repos': reposMap,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
