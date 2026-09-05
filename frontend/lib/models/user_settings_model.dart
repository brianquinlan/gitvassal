import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents user settings and profile metadata in Firestore under users/{uid}.
class UserSettingsModel {
  final String uid;
  final String? githubAccessToken;
  final String? githubUsername;
  final String? geminiApiKey;
  final Map<String, DateTime?> monitoredRepos;
  final DateTime? updatedAt;

  UserSettingsModel({
    required this.uid,
    this.githubAccessToken,
    this.githubUsername,
    this.geminiApiKey,
    this.monitoredRepos = const {},
    this.updatedAt,
  });

  /// Convenience getter for repository names.
  List<String> get monitoredRepoNames => monitoredRepos.keys.toList();

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

    Map<String, DateTime?> parseMonitoredRepos(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString().trim(), parseDate(v)));
      }
      return {};
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

  /// Converts model to Firestore document format.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'github_access_token': githubAccessToken?.trim().isEmpty ?? true ? null : githubAccessToken!.trim(),
      'github_username': githubUsername?.trim().isEmpty ?? true ? null : githubUsername!.trim(),
      'gemini_api_key': geminiApiKey?.trim().isEmpty ?? true ? null : geminiApiKey!.trim(),
      'monitored_repos': monitoredRepos,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
