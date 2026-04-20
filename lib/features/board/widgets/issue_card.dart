import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../issues/models/issue_model.dart';
import '../theme/board_colors.dart';

class IssueCard extends StatelessWidget {
  const IssueCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.onLongPress,
  });

  final IssueModel issue;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static String? _initials(String? email) {
    if (email == null || email.isEmpty) return null;
    final local = email.split('@').first;
    final parts = local.split(RegExp(r'[._-]')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (local.isNotEmpty) {
      final n = local.length >= 2 ? 2 : local.length;
      return local.substring(0, n).toUpperCase();
    }
    return null;
  }

  /// P1 / P2 / P3 color coding; maps legacy `highest` / `high` / `medium` etc.
  static ({Color bg, Color fg, String label})? _priorityBadge(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.isEmpty) return null;

    String norm = s;
    if (s == 'highest') norm = 'p1';
    if (s == 'high') norm = 'p2';
    if (s == 'medium') norm = 'p3';
    if (s == 'low') norm = 'p4';
    if (s == 'lowest') norm = 'p5';
    if (s == 'exposed_to_client') norm = 'p3';

    switch (norm) {
      case 'p1':
        return (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          label: 'P1',
        );
      case 'p2':
        return (
          bg: const Color(0xFFFFEDD5),
          fg: const Color(0xFFC2410C),
          label: 'P2',
        );
      case 'p3':
        return (
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1D4ED8),
          label: 'P3',
        );
      case 'p4':
        return (
          bg: const Color(0xFFF3F4F6),
          fg: const Color(0xFF4B5563),
          label: 'P4',
        );
      case 'p5':
        return (
          bg: const Color(0xFFF3F4F6),
          fg: const Color(0xFF6B7280),
          label: 'P5',
        );
      default:
        if (s.startsWith('p') && s.length <= 3) {
          final label = (raw ?? '').trim().toUpperCase();
          return (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF4B5563), label: label);
        }
        final fallback = (raw ?? '').trim();
        if (fallback.isEmpty) {
          return (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF4B5563), label: '—');
        }
        return (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF4B5563), label: fallback);
    }
  }

  static String _shortDueDate(DateTime d) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  TextStyle _inter(Color color, double fontSize, FontWeight w) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: w,
      color: color,
      height: 1.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (stFg, stBg) = BoardColors.statusPair(issue.status);
    final initials = _initials(issue.assigneeEmail);
    final accent = BoardColors.statusAccent(issue.status);
    final outline = scheme.outlineVariant.withValues(alpha: 0.45);
    const radius = BorderRadius.all(Radius.circular(10));
    final priority = _priorityBadge(issue.internalPriority);
    final due = issue.dueDate;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: radius,
            border: Border.all(color: outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (issue.issueKey != null && issue.issueKey!.isNotEmpty)
                          Text(
                            issue.issueKey!,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                              height: 1.1,
                            ),
                          ),
                        if (issue.issueKey != null && issue.issueKey!.isNotEmpty)
                          const SizedBox(height: 2),
                        Text(
                          issue.summary.isEmpty ? '(Untitled task)' : issue.summary,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.22,
                            color: scheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (issue.workflowStatus != null &&
                            issue.workflowStatus!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            issue.workflowStatus!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.2,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: stBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      issue.status.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: stFg,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                  if (priority != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: priority.bg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        priority.label,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: priority.fg,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  if (due != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Due Date',
                                          style: _inter(
                                            scheme.onSurfaceVariant,
                                            10,
                                            FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          ' ${_shortDueDate(due)}',
                                          style: _inter(
                                            scheme.onSurface,
                                            10,
                                            FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (initials != null) ...[
                              const SizedBox(width: 6),
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: scheme.secondaryContainer,
                                child: Text(
                                  initials,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSecondaryContainer,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
