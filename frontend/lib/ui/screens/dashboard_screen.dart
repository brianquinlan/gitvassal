import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_settings_model.dart';
import '../../services/firestore_service.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/task_table.dart';

/// Main Dashboard Screen displaying the TaskVassal UI across the full width.
class DashboardScreen extends StatelessWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Header with App Title, Settings Icon, and User Profile Icon
            AppHeader(user: user),

            // Realtime Firestore Streams for Settings & Tasks
            Expanded(
              child: StreamBuilder<UserSettingsModel>(
                stream: firestoreService.streamUserSettings(user.uid),
                builder: (context, settingsSnapshot) {
                  final settings = settingsSnapshot.data;
                  final needsConfig = settings != null &&
                      (settings.githubAccessToken == null ||
                          settings.monitoredRepos.isEmpty);

                  return StreamBuilder<List<TaskModel>>(
                    stream: firestoreService.streamTasks(user.uid),
                    builder: (context, taskSnapshot) {
                      final isLoading = taskSnapshot.connectionState ==
                          ConnectionState.waiting;
                      final allTasks = taskSnapshot.data ?? [];
                      final filteredTasks = appState.filterTasks(allTasks);

                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Setup Notice Banner if token or repos are missing
                                if (needsConfig) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFBFDBFE),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'To automatically sync and rank your GitHub tasks, configure your GitHub Personal Access Token and Monitored Repositories in Settings.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF1E40AF),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton(
                                          onPressed: () => SettingsDialog.show(
                                            context,
                                            user.uid,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryBlue,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text('Open Settings'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Task Table View
                                TaskTable(
                                  uid: user.uid,
                                  tasks: filteredTasks,
                                  isLoading: isLoading,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
