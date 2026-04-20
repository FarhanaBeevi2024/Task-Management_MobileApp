import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../issues/models/issue_model.dart';
import '../../issues/models/issue_status.dart';
import 'issue_card.dart';

/// Task card with horizontal swipe actions and an overflow control for the actions sheet.
class BoardIssueTile extends StatelessWidget {
  const BoardIssueTile({
    super.key,
    required this.issue,
    required this.workflowColumns,
    required this.onOpenDetail,
    required this.onOpenActions,
    required this.onEdit,
    required this.onSetStatus,
    this.slidableGroupTag,
  });

  final IssueModel issue;
  final List<IssueStatus> workflowColumns;
  final VoidCallback onOpenDetail;
  final VoidCallback onOpenActions;
  final VoidCallback onEdit;
  final Future<void> Function(IssueStatus status) onSetStatus;

  /// Groups [Slidable]s so opening one closes others (e.g. per project board).
  final String? slidableGroupTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final idx = workflowColumns.indexOf(issue.status);
    final prev = (idx > 0) ? workflowColumns[idx - 1] : null;
    final next = (idx >= 0 && idx < workflowColumns.length - 1)
        ? workflowColumns[idx + 1]
        : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Slidable(
        key: ValueKey('slidable-${issue.id}'),
        groupTag: slidableGroupTag,
        closeOnScroll: true,
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.48,
          children: [
            SlidableAction(
              onPressed: (_) {
                onEdit();
              },
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              icon: Icons.edit_outlined,
              label: 'Edit',
            ),
            SlidableAction(
              onPressed: (_) {
                onOpenActions();
              },
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              icon: Icons.tune_rounded,
              label: 'More',
            ),
          ],
        ),
        endActionPane: issue.status == IssueStatus.done
            ? null
            : ActionPane(
                motion: const DrawerMotion(),
                extentRatio: (prev != null && next != null)
                    ? 0.66
                    : (prev != null || next != null)
                        ? 0.48
                        : 0.24,
                children: [
                  if (prev != null)
                    SlidableAction(
                      onPressed: (_) {
                        onSetStatus(prev);
                      },
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: scheme.onSurface,
                      icon: Icons.arrow_back_rounded,
                      label: 'Back',
                    ),
                  SlidableAction(
                    onPressed: (_) {
                      onSetStatus(IssueStatus.done);
                    },
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    icon: Icons.check_rounded,
                    label: 'Done',
                  ),
                  if (next != null)
                    SlidableAction(
                      onPressed: (_) {
                        onSetStatus(next);
                      },
                      backgroundColor: scheme.tertiary,
                      foregroundColor: scheme.onTertiary,
                      icon: Icons.arrow_forward_rounded,
                      label: 'Next',
                    ),
                ],
              ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IssueCard(
              issue: issue,
              onTap: onOpenDetail,
              onLongPress: onOpenActions,
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpenActions,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 22,
                      color: scheme.onSurfaceVariant.withOpacity(0.9),
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
}
