import 'package:flutter/material.dart';
import '../../models/task_model.dart';
import '../theme.dart';
import 'task_row.dart';

/// Clean scrollable list of prioritized tasks with no surrounding container chrome.
class TaskTable extends StatelessWidget {
  final String uid;
  final List<TaskModel> tasks;
  final bool isLoading;

  const TaskTable({
    super.key,
    required this.uid,
    required this.tasks,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppTheme.textPlaceholder,
            ),
            const SizedBox(height: 12),
            const Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Configure your GitHub token and monitored repositories in Settings.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskRow(
          key: ValueKey(task.id),
          uid: uid,
          task: task,
        );
      },
    );
  }
}
