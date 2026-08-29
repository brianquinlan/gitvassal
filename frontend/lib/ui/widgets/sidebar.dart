import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Left sidebar navigation matching the TaskVassal sidebar design.
class Sidebar extends StatefulWidget {
  final String uid;

  const Sidebar({super.key, required this.uid});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isRefreshingSync = false;

  Future<void> _handleRefreshSync() async {
    setState(() => _isRefreshingSync = true);
    try {
      final firestoreService = context.read<FirestoreService>();
      await firestoreService.markAllTasksNeedsRerank(widget.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync requested: tasks marked for reranking.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger sync: $e'),
            backgroundColor: AppTheme.dotRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshingSync = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBackground,
        border: Border(
          right: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar Header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.developer_board,
                  size: 16,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'TaskVassal',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 32, top: 2),
            child: Text(
              'Developer Dashboard',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Navigation Links
          _buildNavItem(
            icon: Icons.view_list_outlined,
            label: 'All Issues',
            isSelected: appState.selectedCategory == FilterCategory.all,
            onTap: () => appState.setSelectedCategory(FilterCategory.all),
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            icon: Icons.assignment_ind_outlined,
            label: 'Assigned',
            isSelected: appState.selectedCategory == FilterCategory.assigned,
            onTap: () => appState.setSelectedCategory(FilterCategory.assigned),
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            icon: Icons.add_circle_outline,
            label: 'Created',
            isSelected: appState.selectedCategory == FilterCategory.created,
            onTap: () => appState.setSelectedCategory(FilterCategory.created),
          ),
          const SizedBox(height: 4),
          _buildNavItem(
            icon: Icons.alternate_email,
            label: 'Mentioned',
            isSelected: appState.selectedCategory == FilterCategory.mentioned,
            onTap: () => appState.setSelectedCategory(FilterCategory.mentioned),
          ),

          const Spacer(),

          // Refresh Sync Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRefreshingSync ? null : _handleRefreshSync,
              icon: _isRefreshingSync
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.textSecondary),
                    )
                  : const Icon(Icons.sync, size: 16, color: AppTheme.textSecondary),
              label: Text(
                _isRefreshingSync ? 'Syncing...' : 'Refresh Sync',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5E7EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
