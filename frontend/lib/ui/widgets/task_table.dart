import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../theme.dart';
import 'task_row.dart';

/// Dynamic scrollable list that lazily loads tasks as they scroll into view.
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
  final List<TaskModel> _tasks = [];
  final List<DocumentSnapshot> _snapshots = [];

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialTasks();
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

    // Trigger next page when scrolling within 250px of the bottom
    if (currentScroll >= (maxScroll - 250)) {
      _loadMoreTasks();
    }
  }

  Future<void> _loadInitialTasks() async {
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = null;
    });

    try {
      final firestoreService = context.read<FirestoreService>();
      final snapshot = await firestoreService.fetchTasksPage(
        uid: widget.uid,
        limit: _pageSize,
      );

      final loadedTasks = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _tasks.clear();
          _snapshots.clear();
          _tasks.addAll(loadedTasks);
          _snapshots.addAll(snapshot.docs);
          _hasMore = snapshot.docs.length >= _pageSize;
          _isLoadingInitial = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoadingInitial = false;
        });
      }
    }
  }

  Future<void> _loadMoreTasks() async {
    if (_isLoadingMore || !_hasMore || _snapshots.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final firestoreService = context.read<FirestoreService>();
      final snapshot = await firestoreService.fetchTasksPage(
        uid: widget.uid,
        limit: _pageSize,
        startAfter: _snapshots.last,
      );

      final loadedTasks = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _tasks.addAll(loadedTasks);
          _snapshots.addAll(snapshot.docs);
          _hasMore = snapshot.docs.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.dotRed),
              const SizedBox(height: 12),
              Text(
                'Error loading tasks: $_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInitialTasks,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInitialTasks,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight > 0 ? constraints.maxHeight : 300,
              child: Center(
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
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialTasks,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _tasks.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _tasks.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final task = _tasks[index];
          return TaskRow(
            key: ValueKey(task.id),
            uid: widget.uid,
            task: task,
          );
        },
      ),
    );
  }
}
