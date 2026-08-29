import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/app_header.dart';
import '../widgets/task_table.dart';

/// Main Dashboard Screen displaying the TaskVassal scrollable list directly under the top bar.
class DashboardScreen extends StatelessWidget {
  final User user;

  const DashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Header with App Title, Settings Icon, and User Profile Icon
            AppHeader(user: user),

            // Directly scrollable list of tasks filling the screen
            Expanded(
              child: StreamBuilder<List<TaskModel>>(
                stream: firestoreService.streamTasks(user.uid),
                builder: (context, taskSnapshot) {
                  final isLoading =
                      taskSnapshot.connectionState == ConnectionState.waiting;
                  final tasks = taskSnapshot.data ?? [];

                  return TaskTable(
                    uid: user.uid,
                    tasks: tasks,
                    isLoading: isLoading,
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
