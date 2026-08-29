import 'package:flutter/foundation.dart';
import '../models/task_model.dart';

enum FilterCategory {
  all,
  assigned,
  created,
  mentioned,
}

enum NavTab {
  dashboard,
  issues,
  pullRequests,
}

/// Global Application State for UI navigation, searching, and filtering.
class AppState extends ChangeNotifier {
  FilterCategory _selectedCategory = FilterCategory.all;
  NavTab _selectedTab = NavTab.dashboard;
  String _searchQuery = '';
  bool _isSyncing = false;
  final Set<String> _refreshingTaskIds = {};

  FilterCategory get selectedCategory => _selectedCategory;
  NavTab get selectedTab => _selectedTab;
  String get searchQuery => _searchQuery;
  bool get isSyncing => _isSyncing;
  Set<String> get refreshingTaskIds => _refreshingTaskIds;

  void setSelectedCategory(FilterCategory category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  void setSelectedTab(NavTab tab) {
    if (_selectedTab != tab) {
      _selectedTab = tab;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSyncing(bool syncing) {
    _isSyncing = syncing;
    notifyListeners();
  }

  void setTaskRefreshing(String taskId, bool refreshing) {
    if (refreshing) {
      _refreshingTaskIds.add(taskId);
    } else {
      _refreshingTaskIds.remove(taskId);
    }
    notifyListeners();
  }

  bool isTaskRefreshing(String taskId) => _refreshingTaskIds.contains(taskId);

  /// Filters and searches a list of tasks based on selected category and query.
  List<TaskModel> filterTasks(List<TaskModel> tasks) {
    var result = tasks;

    // Apply Category filter
    if (_selectedCategory != FilterCategory.all) {
      final categoryName = _selectedCategory.name;
      result = result.where((task) {
        return task.sources.contains(categoryName);
      }).toList();
    }

    // Apply Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((task) {
        final title = (task.githubIssueTitle ?? '').toLowerCase();
        final repo = task.repoFullName.toLowerCase();
        final numStr = task.issueNumber?.toString() ?? '';
        final owner = (task.owner ?? '').toLowerCase();

        return title.contains(q) ||
            repo.contains(q) ||
            numStr.contains(q) ||
            owner.contains(q);
      }).toList();
    }

    return result;
  }
}
