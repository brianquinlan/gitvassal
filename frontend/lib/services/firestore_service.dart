import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/user_settings_model.dart';

/// Direct Firestore interaction service.
/// Enforces client write constraints: only writes to user settings and Task.priority_needs_updated.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Real-time stream of prioritized tasks for the authenticated user with a dynamic limit.
  Stream<List<TaskModel>> streamTasks(String uid, {int limit = 20}) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('priority', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Fetches the user settings once.
  Future<UserSettingsModel> getUserSettings(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      return UserSettingsModel(uid: uid);
    }
    return UserSettingsModel.fromFirestore(doc);
  }

  /// Writes user settings to users/{uid}.
  /// This includes github_access_token, github_username, gemini_api_key, and monitored_repos.
  Future<void> updateUserSettings(String uid, UserSettingsModel settings) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(settings.toFirestoreMap(), SetOptions(merge: true));
  }

  /// Writes priority_needs_updated = true to a specific task document in Firestore.
  /// This is triggered when the user clicks the "Refresh" button on an issue row.
  /// The Cloud Function `on_task_written` will detect this and enqueue task reranking.
  Future<void> markTaskNeedsRerank(String uid, String taskId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(taskId)
        .set({
      'priority_needs_updated': true,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sets priority to 0.0, records thumbs_down_at, and sets priority_needs_updated = false.
  /// This deprioritizes the task until new activity occurs on GitHub after thumbs_down_at.
  Future<void> thumbsDownTask(String uid, String taskId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .doc(taskId)
        .set({
      'priority': 0.0,
      'thumbs_down_at': FieldValue.serverTimestamp(),
      'priority_needs_updated': false,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
