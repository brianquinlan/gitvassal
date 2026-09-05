import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/task_model.dart';
import '../../services/firestore_service.dart';
import '../theme.dart';

/// Single task row component in the TaskVassal list.
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
  bool _isRefreshing = false;
  bool _isDeprioritizing = false;

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
    setState(() => _isRefreshing = true);
    try {
      final firestoreService = context.read<FirestoreService>();
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
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleThumbsDown() async {
    setState(() => _isDeprioritizing = true);
    try {
      final firestoreService = context.read<FirestoreService>();
      await firestoreService.thumbsDownTask(widget.uid, widget.task.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deprioritized "${widget.task.displayTitle}" (priority set to 0.0)'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF475569),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deprioritizing task: $e'),
            backgroundColor: AppTheme.dotRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeprioritizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRefreshing = _isRefreshing || widget.task.priorityNeedsUpdated;
    final isThumbedDown = widget.task.thumbsDownAt != null;

    final isPR = widget.task.isPr;
    final IconData typeIcon = isPR ? Icons.merge_type : Icons.adjust;
    final String typeTooltip = isPR ? 'Pull Request' : 'Issue';
    final Color iconColor = widget.task.priorityNeedsUpdated
        ? AppTheme.dotRed
        : const Color(0xFF1A7F37);

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Issue Column (PR/Issue Icon + Title)
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Tooltip(
                    message: typeTooltip,
                    child: Icon(
                      typeIcon,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Clickable Title
                  Expanded(
                    child: InkWell(
                      onTap: _openIssueUrl,
                      child: Text(
                        widget.task.displayTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
                        ),
                      ),
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

            // Priority Score Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.task.priorityNeedsUpdated
                    ? const Color(0xFFF1F5F9)
                    : (isThumbedDown
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFEFF6FF)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.task.priorityNeedsUpdated
                      ? AppTheme.borderMedium
                      : (isThumbedDown
                          ? AppTheme.borderMedium
                          : const Color(0xFFBFDBFE)),
                  width: 1,
                ),
              ),
              child: Text(
                widget.task.priority.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.task.priorityNeedsUpdated
                      ? AppTheme.textMuted
                      : (isThumbedDown
                          ? AppTheme.textMuted
                          : const Color(0xFF1D4ED8)),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Actions Column (Thumbs Down & Refresh)
            SizedBox(
              width: 155,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Thumbs Down Button
                  IconButton(
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    tooltip: isThumbedDown
                        ? 'Deprioritized (priority 0.0)'
                        : 'Deprioritize (thumbs down)',
                    icon: _isDeprioritizing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textMuted),
                          )
                        : Icon(
                            isThumbedDown ? Icons.thumb_down : Icons.thumb_down_outlined,
                            size: 16,
                            color: isThumbedDown ? AppTheme.dotRed : AppTheme.textMuted,
                          ),
                    onPressed: (_isDeprioritizing || isRefreshing) ? null : _handleThumbsDown,
                  ),
                  const SizedBox(width: 4),

                  // Refresh Button
                  OutlinedButton.icon(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
