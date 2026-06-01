import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_page_routes.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../board/theme/board_colors.dart';
import '../../issues/models/issue_model.dart';
import '../../issues/providers/issues_providers.dart';
import '../../issues/screens/issue_detail_screen.dart';
import '../../projects/models/project_model.dart';
import '../../projects/providers/projects_providers.dart';
import '../../projects/screens/projects_list_screen.dart';

/// Local calendar date key `YYYY-MM-DD` (matches web grouping on calendar dates).
String _ymdLocal(DateTime d) {
  final l = d.toLocal();
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final day = l.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String? _issueDueDateKey(IssueModel issue) {
  final d = issue.dueDate;
  if (d == null) return null;
  return _ymdLocal(d);
}

Map<String, List<IssueModel>> _issuesByDueDate(List<IssueModel> issues) {
  final map = <String, List<IssueModel>>{};
  for (final issue in issues) {
    final key = _issueDueDateKey(issue);
    if (key == null) continue;
    map.putIfAbsent(key, () => []).add(issue);
  }
  for (final list in map.values) {
    list.sort((a, b) {
      final ka = a.issueKey ?? '';
      final kb = b.issueKey ?? '';
      final c = ka.compareTo(kb);
      if (c != 0) return c;
      return a.summary.compareTo(b.summary);
    });
  }
  return map;
}

/// Leading blank cells when the month grid starts on Sunday (same as web).
int _leadingBlankCount(DateTime firstOfMonth) => firstOfMonth.weekday % 7;

/// Seven-day rows for the month grid (each row may have `null` padding cells).
List<List<DateTime?>> _weeksForMonthGrid(DateTime monthStart) {
  final days = _daysForMonthGrid(monthStart);
  final weeks = <List<DateTime?>>[];
  for (var i = 0; i < days.length; i += 7) {
    weeks.add(days.sublist(i, i + 7));
  }
  return weeks;
}

List<DateTime?> _daysForMonthGrid(DateTime monthStart) {
  final first = DateTime(monthStart.year, monthStart.month, 1);
  final lead = _leadingBlankCount(first);
  final days = <DateTime?>[];
  for (var i = 0; i < lead; i++) {
    days.add(null);
  }
  var cursor = first;
  final m = first.month;
  while (cursor.month == m) {
    days.add(cursor);
    cursor = cursor.add(const Duration(days: 1));
  }
  while (days.length % 7 != 0) {
    days.add(null);
  }
  return days;
}

String _monthYearLabel(DateTime monthStart) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${names[monthStart.month - 1]} ${monthStart.year}';
}

/// Month grid of issues by due date (parity with web `CalendarView.jsx`).
class ProjectCalendarScreen extends ConsumerStatefulWidget {
  const ProjectCalendarScreen({super.key});

  @override
  ConsumerState<ProjectCalendarScreen> createState() => _ProjectCalendarScreenState();
}

class _ProjectCalendarScreenState extends ConsumerState<ProjectCalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _visibleMonth = DateTime(n.year, n.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final projectsAsync = ref.watch(projectsListProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorStateView(
        error: e,
        onRetry: () => ref.invalidate(projectsListProvider),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return EmptyStateView(
            title: 'No projects',
            message: 'Create a project from the Projects tab to use the calendar.',
            actionLabel: 'Refresh',
            onAction: () => ref.invalidate(projectsListProvider),
          );
        }

        final sid = selectedId;
        final effectiveId =
            sid != null && projects.any((p) => p.id == sid) ? sid : projects.first.id;
        final project = projects.firstWhere(
          (p) => p.id == effectiveId,
          orElse: () => projects.first,
        );
        final issuesAsync = ref.watch(issuesForProjectProvider(effectiveId));

        final bottomPad = projectsTabListBottomPadding(context);

        Future<void> onRefresh() async {
          ref.invalidate(projectsListProvider);
          ref.invalidate(issuesForProjectProvider(effectiveId));
          await ref.read(issuesForProjectProvider(effectiveId).future);
        }

        // Column + Expanded needs a bounded parent (not inside ScrollView).
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                project.name,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Tasks and issues by due date',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _ProjectPicker(
                projects: projects,
                selectedId: effectiveId,
                onChanged: (id) {
                  ref.read(selectedProjectIdProvider.notifier).state = id;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Previous month',
                  ),
                  Expanded(
                    child: Text(
                      _monthYearLabel(_visibleMonth),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Next month',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: onRefresh,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          width: constraints.maxWidth,
                          child: issuesAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(
                              child: Text(
                                '$e',
                                style: TextStyle(color: cs.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            data: (issues) {
                              final byDate = _issuesByDueDate(issues);
                              final todayKey = _ymdLocal(DateTime.now());
                              final weeks = _weeksForMonthGrid(_visibleMonth);
                              final dueCount = issues.where((i) => i.dueDate != null).length;
                              return _ExpandedMonthCalendar(
                                weeks: weeks,
                                byDate: byDate,
                                todayKey: todayKey,
                                dueCountLabel:
                                    '$dueCount issue(s) with a due date in this project.',
                                onIssueTap: (issue) {
                                  Navigator.of(context).push(
                                    AppPageRoutes.fade(IssueDetailScreen(issue: issue)),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Fills remaining viewport height and splits it evenly across week rows.
class _ExpandedMonthCalendar extends StatelessWidget {
  const _ExpandedMonthCalendar({
    required this.weeks,
    required this.byDate,
    required this.todayKey,
    required this.dueCountLabel,
    required this.onIssueTap,
  });

  final List<List<DateTime?>> weeks;
  final Map<String, List<IssueModel>> byDate;
  final String todayKey;
  final String dueCountLabel;
  final void Function(IssueModel issue) onIssueTap;

  static const _weekdayRowHeight = 22.0;
  static const _weekdayGap = 8.0;
  static const _rowGap = 6.0;
  static const _footerGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final weekCount = weeks.length;
        final gaps = _weekdayGap + (weekCount > 0 ? (weekCount - 1) * _rowGap : 0) + _footerGap;
        const footerTextHeight = 18.0;
        final gridHeight = (constraints.maxHeight -
                _weekdayRowHeight -
                gaps -
                footerTextHeight)
            .clamp(120.0, constraints.maxHeight);
        final rowHeight =
            weekCount > 0 ? (gridHeight - (weekCount - 1) * _rowGap) / weekCount : gridHeight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _weekdayRowHeight,
              child: Row(
                children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: _weekdayGap),
            for (var w = 0; w < weeks.length; w++)
              Padding(
                padding: EdgeInsets.only(bottom: w < weeks.length - 1 ? _rowGap : 0),
                child: SizedBox(
                  height: rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in weeks[w])
                        Expanded(
                          child: day == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: _CalendarDayCell(
                                    day: day,
                                    isToday: _ymdLocal(day) == todayKey,
                                    issues: byDate[_ymdLocal(day)] ?? [],
                                    stretch: true,
                                    onIssueTap: onIssueTap,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: _footerGap),
            Text(
              dueCountLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({
    required this.projects,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ProjectModel> projects;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Project',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: projects.any((p) => p.id == selectedId) ? selectedId : projects.first.id,
          items: projects
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.key != null && p.key!.trim().isNotEmpty ? '${p.name} (${p.key})' : p.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// Single-line key + summary with ellipsis (narrow grid cells cannot fit a [Row] of two texts).
class _IssuePillLine extends StatelessWidget {
  const _IssuePillLine({required this.issue, required this.theme});

  final IssueModel issue;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final fg = BoardColors.statusPair(issue.status).$1;
    final base = theme.textTheme.labelSmall?.copyWith(color: fg, height: 1.15) ??
        TextStyle(fontSize: 11, color: fg, height: 1.15);
    final key = issue.issueKey?.trim();
    final summary = issue.summary.trim().isEmpty ? '(Untitled)' : issue.summary;
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          if (key != null && key.isNotEmpty)
            TextSpan(
              text: '$key ',
              style: base.copyWith(fontWeight: FontWeight.w700),
            ),
          TextSpan(text: summary),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isToday,
    required this.issues,
    required this.onIssueTap,
    this.stretch = false,
  });

  final DateTime day;
  final bool isToday;
  final List<IssueModel> issues;
  final void Function(IssueModel issue) onIssueTap;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasIssues = issues.isNotEmpty;
    final border = isToday
        ? Border.all(color: cs.primary, width: 2)
        : Border.all(color: cs.outlineVariant.withValues(alpha: hasIssues ? 0.5 : 0.35));
    final dayStyle = hasIssues
        ? theme.textTheme.titleSmall
        : theme.textTheme.labelLarge;

    final issueWidgets = <Widget>[
      for (final issue in issues.take(stretch ? 6 : 3))
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: InkWell(
            onTap: () => onIssueTap(issue),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              decoration: BoxDecoration(
                color: BoardColors.statusPair(issue.status).$2,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _IssuePillLine(
                issue: issue,
                theme: theme,
              ),
            ),
          ),
        ),
      if (issues.length > (stretch ? 6 : 3))
        Text(
          '+${issues.length - (stretch ? 6 : 3)} more',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
    ];

    final cellChildren = <Widget>[
      Row(
        children: [
          Flexible(
            child: Text(
              '${day.day}',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: dayStyle?.copyWith(
                fontWeight: FontWeight.w700,
                color: isToday ? cs.primary : cs.onSurface,
              ),
            ),
          ),
          if (hasIssues) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${issues.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      if (hasIssues) ...[
        const SizedBox(height: 4),
        if (stretch)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              children: issueWidgets,
            ),
          )
        else
          ...issueWidgets,
      ] else if (stretch)
        const Spacer(),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: border,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, hasIssues ? 6 : 4, 4, hasIssues ? 6 : 4),
        child: Column(
          mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cellChildren,
        ),
      ),
    );
  }
}
