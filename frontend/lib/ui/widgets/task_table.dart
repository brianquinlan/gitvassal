import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../theme.dart';
import 'task_row.dart';

/// Dynamic scrollable list that lazily loads tasks as they scroll into view
/// while monitoring real-time Firestore ranking updates via live snapshots.
class TaskTable extends StatefulWidget {
  final String uid;

  const TaskTable({
    super.key,
    required this.uid,
  });

  @override
  State<TaskTable> createState() => _TaskTableState();
}

class _TaskTableState extends State<TaskTable> {
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  int _limit = _pageSize;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // Trigger more items when scrolling within 250px of the bottom
    if (currentScroll >= (maxScroll - 250) && _hasMore) {
      setState(() {
        _limit += _pageSize;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService>();

    return StreamBuilder<List<TaskModel>>(
      stream: firestoreService.streamTasks(widget.uid, limit: _limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2.5),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.dotRed),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading tasks: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }

        final tasks = snapshot.data ?? [];
        _hasMore = tasks.length >= _limit;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: AppTheme.textPlaceholder,
                ),
                SizedBox(height: 12),
                Text(
                  'No tasks found',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Configure your GitHub access token and monitored repos in Settings.',
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
          controller: _scrollController,
          itemCount: tasks.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == tasks.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final task = tasks[index];
            return TaskRow(
              key: ValueKey(task.id),
              uid: widget.uid,
              task: task,
            );
          },
        );
      },
    );
  }
}
