import 'package:flutter/material.dart';

import '../../issues/models/issue_model.dart';
import '../../issues/models/issue_status.dart';
import '../theme/board_colors.dart';
import 'board_issue_tile.dart';

/// One Kanban column: header + vertically scrollable task cards (matches web `board-column`).
class KanbanColumn extends StatelessWidget {
  const KanbanColumn({
    super.key,
    required this.column,
    required this.workflowColumns,
    required this.issues,
    required this.projectId,
    required this.onIssueTap,
    required this.onIssueActions,
    required this.onIssueEdit,
    required this.onIssueSetStatus,
    required this.width,
  });

  final IssueStatus column;
  final List<IssueStatus> workflowColumns;
  final List<IssueModel> issues;
  final String projectId;
  final void Function(IssueModel issue) onIssueTap;
  final void Function(IssueModel issue) onIssueActions;
  final void Function(IssueModel issue) onIssueEdit;
  final Future<void> Function(IssueModel issue, IssueStatus status) onIssueSetStatus;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (accentFg, accentBg) = BoardColors.statusPair(column);

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.6),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    column.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${issues.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accentFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: BoardColors.columnBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: issues.isEmpty
                    ? Center(
                        key: const ValueKey('empty'),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'No tasks in ${column.label}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: ValueKey(
                          'list-${column.apiValue}-$projectId-n${issues.length}',
                        ),
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final issue = issues[i];
                          return BoardIssueTile(
                            slidableGroupTag: 'board-$projectId',
                            issue: issue,
                            workflowColumns: workflowColumns,
                            onOpenDetail: () => onIssueTap(issue),
                            onOpenActions: () => onIssueActions(issue),
                            onEdit: () => onIssueEdit(issue),
                            onSetStatus: (s) => onIssueSetStatus(issue, s),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
