import 'package:flutter/material.dart';

import '../models/issue_model.dart';

/// Compact row for priority / assignee on cards or detail header.
class IssueMetaRow extends StatelessWidget {
  const IssueMetaRow({super.key, required this.issue});

  final IssueModel issue;

  @override
  Widget build(BuildContext context) {
    final p = issue.internalPriority ?? '—';
    final a = issue.assigneeEmail ?? 'Unassigned';
    return Text(
      '$p · $a',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
