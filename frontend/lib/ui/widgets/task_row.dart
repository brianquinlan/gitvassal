import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Single task row component in the TaskVassal Dashboard table.
class TaskRow extends StatefulWidget {
  final String uid;
  final TaskModel task;

  const TaskRow({
    super.key,
    required this.uid,
    required this.task,
  });

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _isHovered = false;

  void _openIssueUrl() async {
    final urlStr = widget.task.githubIssueUrl ??
        (widget.task.owner != null && widget.task.repo != null && widget.task.issueNumber != null
            ? 'https://github.com/${widget.task.owner}/${widget.task.repo}/issues/${widget.task.issueNumber}'
            : null);

    if (urlStr != null) {
      final Uri uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _handleRefresh() async {
    final appState = context.read<AppState>();
    final firestoreService = context.read<FirestoreService>();

    appState.setTaskRefreshing(widget.task.id, true);
    try {
      // Directly write priority_needs_updated = true to Firestore
      await firestoreService.markTaskNeedsRerank(widget.uid, widget.task.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reranking requested for "${widget.task.displayTitle}"'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking task for refresh: $e'),
            backgroundColor: AppTheme.dotRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        appState.setTaskRefreshing(widget.task.id, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isRefreshing = appState.isTaskRefreshing(widget.task.id) || widget.task.priorityNeedsUpdated;

    final badge = widget.task.inferredBadge;
    final (badgeBg, badgeText) = _getBadgeColors(badge);

    // Red dot for high-priority or needs update, Blue dot for normal
    final isHighPriority = widget.task.isHighPriority || widget.task.priorityNeedsUpdated;
    final dotColor = isHighPriority ? AppTheme.dotRed : AppTheme.dotBlue;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF9FAFB) : Colors.white,
          border: const Border(
            bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Issue Column (Expanded)
            Expanded(
              flex: 5,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status dot indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 12),
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: dotColor, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    ),
                  ),

                  // Title + Badges + Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Clickable Title
                        InkWell(
                          onTap: _openIssueUrl,
                          child: Text(
                            widget.task.displayTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Badge + Subtitle Info
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: badgeText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.task.subtitleInfo,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                            if (widget.task.priority > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'Score: ${(widget.task.priority * 100).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Repository Column
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.task.repoFullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Actions Column
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: isRefreshing ? null : _handleRefresh,
                  icon: isRefreshing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textSecondary),
                        )
                      : const Icon(Icons.refresh, size: 14, color: AppTheme.textSecondary),
                  label: Text(
                    isRefreshing ? 'Queued' : 'Refresh',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: AppTheme.borderMedium),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color) _getBadgeColors(String badge) {
    switch (badge.toLowerCase()) {
      case 'bug':
      case 'high-priority':
        return (AppTheme.badgeBugBg, AppTheme.badgeBugText);
      case 'enhancement':
      case 'feat':
        return (AppTheme.badgeEnhancementBg, AppTheme.badgeEnhancementText);
      case 'docs':
        return (AppTheme.badgeDocsBg, AppTheme.badgeDocsText);
      case 'assigned':
      case 'mentioned':
      case 'created':
        return (AppTheme.badgePurpleBg, AppTheme.badgePurpleText);
      default:
        return (const Color(0xFFF3F4F6), AppTheme.textSecondary);
    }
  }
}
