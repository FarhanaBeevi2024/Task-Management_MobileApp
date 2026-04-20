import 'package:flutter/material.dart';

import '../../issues/models/issue_status.dart';

/// Matches web [IssueCard] / [JiraBoard] status styling.
class BoardColors {
  BoardColors._();

  static Color columnBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      scheme.surfaceContainerHighest.withOpacity(0.65),
      scheme.surface,
    );
  }

  static Color boardScaffoldBackground(BuildContext context) {
    return const Color(0xFFF8FAFC);
  }

  static (Color fg, Color bg) statusPair(IssueStatus status) {
    switch (status) {
      case IssueStatus.toDo:
        return (const Color(0xFF6B7280), const Color(0xFFF3F4F6));
      case IssueStatus.inProgress:
        return (const Color(0xFF3B82F6), const Color(0xFFDBEAFE));
      case IssueStatus.inReview:
        return (const Color(0xFFF59E0B), const Color(0xFFFEF3C7));
      case IssueStatus.done:
        return (const Color(0xFF10B981), const Color(0xFFD1FAE5));
    }
  }

  static Color statusAccent(IssueStatus status) => statusPair(status).$1;
}
