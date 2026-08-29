import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../models/user_settings_model.dart';

/// Direct Firestore interaction service.
/// Enforces client write constraints: only writes to user settings and Task.priority_needs_updated.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Real-time stream of prioritized tasks for the authenticated user.
  Stream<List<TaskModel>> streamTasks(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();
      // Sort descending by priority (highest priority first)
      tasks.sort((a, b) => b.priority.compareTo(a.priority));
      return tasks;
    });
  }

  /// Real-time stream of the user profile and settings document.
  Stream<UserSettingsModel> streamUserSettings(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return UserSettingsModel(uid: uid);
      }
      return UserSettingsModel.fromFirestore(doc);
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

  /// Marks all tasks for the user as needing rerank, and updates user profile timestamp.
  /// Triggered when the user clicks "Refresh Sync" in the sidebar.
  Future<void> markAllTasksNeedsRerank(String uid) async {
    final tasksCol = _firestore.collection('users').doc(uid).collection('tasks');
    final snapshot = await tasksCol.get();

    if (snapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.set(doc.reference, {
          'priority_needs_updated': true,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }

    // Also touch updated_at on user profile to notify triggers if needed
    await _firestore.collection('users').doc(uid).set({
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
