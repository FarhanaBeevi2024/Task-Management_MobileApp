import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_page_routes.dart';
import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_footer_nav.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/account_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_skeletons.dart';
import '../../issues/models/issue_model.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/providers/issues_providers.dart';
import '../../issues/screens/issue_detail_screen.dart';
import '../../issues/screens/task_form_screen.dart';
import '../../issues/widgets/issue_task_actions_sheet.dart';
import '../../projects/models/project_model.dart';
import '../../projects/providers/projects_providers.dart'
    show projectsListProvider, selectedProjectIdProvider, projectMembersProvider;
import 'board_status_tasks_screen.dart';
import '../providers/board_providers.dart';
import '../theme/board_colors.dart';
import '../widgets/board_issue_tile.dart';
import '../widgets/kanban_column.dart';

/// Horizontal Kanban: swipe actions, action sheet, skeleton loading, animated transitions.
///
/// When [showAppBarBack] is true (full-screen route from project tap), an [AppBar] with
/// back navigation is shown and the project banner is omitted (title is in the app bar).
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key, this.showAppBarBack = false});

  /// Pushed route from [context.push] after selecting a project; shows back to Projects.
  final bool showAppBarBack;

  static const double _columnWidth = 292;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ref.watch(selectedProjectIdProvider);
    final canCreateIssues = ref.watch(sessionPermissionsProvider).maybeWhen(
          data: (p) => p.project.canCreateIssues,
          orElse: () => false,
        );
    ref.listen<String?>(selectedProjectIdProvider, (prev, next) {
      if (prev != next) {
        ref.read(boardSearchQueryProvider.notifier).state = '';
        // Default to To Do when switching projects (reference behavior).
        ref.read(boardStatusFilterProvider.notifier).state = IssueStatus.toDo.apiValue;
      }
    });
    final columns = ref.watch(visibleBoardColumnsProvider);
    final issuesAsync = ref.watch(projectIssuesProvider);
    final projectsAsync = ref.watch(projectsListProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    final project = projectsAsync.whenOrNull(
      data: (List<ProjectModel> list) {
        final id = projectId;
        if (id == null || id.isEmpty) return null;
        for (final p in list) {
          if (p.id == id) return p;
        }
        return null;
      },
    );
    final projectName = project?.name;

    if (projectId == null || projectId.isEmpty) {
      final message = showAppBarBack
          ? 'No project selected. Go back and choose a project.'
          : 'Select a project from the Projects tab to view the board.';
      final body = EmptyStateView(
        title: 'No project selected',
        message: message,
        icon: Icons.folder_open_outlined,
      );
      if (showAppBarBack) {
        return Scaffold(
          backgroundColor: BoardColors.boardScaffoldBackground(context),
          appBar: AppBar(
            backgroundColor: BoardColors.boardScaffoldBackground(context),
            elevation: 0,
            leading: const BackButton(),
            title: const Text('Board'),
          ),
          body: body,
        );
      }
      return body;
    }

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: showAppBarBack
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: const BackButton(),
                title: Text(projectName ?? 'Board'),
                actions: const [
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: AccountMenuButton(),
                  ),
                ],
              )
            : null,
        bottomNavigationBar: const AppFooterNav(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 360),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: issuesAsync.when(
          loading: () => KeyedSubtree(
            key: const ValueKey('board-loading'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (project != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: _ProjectOverviewSection(
                      project: project,
                      onViewMore: () => context.push('/project-overview'),
                    ),
                  ),
                Expanded(
                  child: LoadingSkeletons.kanbanBoard(
                    context,
                    columnWidth: _columnWidth,
                  ),
                ),
              ],
            ),
          ),
          error: (e, _) => KeyedSubtree(
            key: ValueKey('board-error-$e'),
            child: ErrorStateView(
              error: e,
              onRetry: () {
                ref.invalidate(projectIssuesProvider);
                if (projectId.isNotEmpty) {
                  ref.invalidate(projectIssueProgressProvider(projectId));
                }
              },
            ),
          ),
          data: (all) => KeyedSubtree(
            key: ValueKey('board-data-$projectId'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (project != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: _ProjectOverviewSection(
                      project: project,
                      onViewMore: () => context.push('/project-overview'),
                    ),
                  ),
                if (project != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: _TaskOverviewSection(
                        issues: _applyBoardFilters(ref, all, ignoreStatusFilter: true),
                        workflowColumns: columns,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: canCreateIssues
          ? FloatingActionButton.extended(
              onPressed: () => _boardOpenNewTask(context, ref, projectId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            )
          : null,
      ),
    );
  }
}

List<IssueModel> _applyBoardFilters(
  WidgetRef ref,
  List<IssueModel> all, {
  bool ignoreStatusFilter = false,
}) {
  final statusFilter = ignoreStatusFilter ? 'all' : ref.watch(boardStatusFilterProvider);
  final query = ref.watch(boardSearchQueryProvider).trim().toLowerCase();

  bool matchStatus(IssueModel issue) {
    if (statusFilter == 'all') return true;
    return issue.status.apiValue == statusFilter;
  }

  bool matchSearch(IssueModel issue) {
    if (query.isEmpty) return true;
    final hay = _issueSearchHaystack(issue);
    if (hay.isEmpty) return false;
    for (final token in query.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      if (!hay.contains(token)) return false;
    }
    return true;
  }

  return all.where((i) => matchStatus(i) && matchSearch(i)).toList(growable: false);
}

/// Lowercased concatenation of fields users expect “keyword” search to hit.
String _issueSearchHaystack(IssueModel issue) {
  final parts = <String>[
    issue.summary,
    issue.description ?? '',
    issue.issueKey ?? '',
    issue.workflowStatus ?? '',
    issue.assigneeEmail ?? '',
    issue.internalPriority ?? '',
    issue.clientPriority ?? '',
    ...issue.labels,
  ];
  return parts.map((e) => e.toLowerCase()).join(' ');
}

class _BoardFilters extends ConsumerStatefulWidget {
  const _BoardFilters();

  @override
  ConsumerState<_BoardFilters> createState() => _BoardFiltersState();
}

class _BoardFiltersState extends ConsumerState<_BoardFilters> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(boardSearchQueryProvider));
    _searchController.addListener(_syncQueryToProvider);
  }

  void _syncQueryToProvider() {
    final t = _searchController.text;
    if (t != ref.read(boardSearchQueryProvider)) {
      ref.read(boardSearchQueryProvider.notifier).state = t;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_syncQueryToProvider);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(boardSearchQueryProvider, (prev, next) {
      if (_searchController.text != next) {
        _searchController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search keyword',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: scheme.surface.withOpacity(0.72),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.outlineVariant.withOpacity(0.35)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                ref.read(boardSearchQueryProvider.notifier).state = '';
                if (!isCompact) {
                  ref.read(boardStatusFilterProvider.notifier).state = 'all';
                }
              },
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> _boardOpenNewTask(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  final saved = await Navigator.of(context).push<IssueModel>(
    AppPageRoutes.fade(TaskFormScreen(projectId: projectId)),
  );
  if (saved != null) invalidateProjectTasksData(ref, projectId);
}

Future<void> _boardSetIssueStatus(
  BuildContext context,
  WidgetRef ref,
  String projectId,
  IssueModel issue,
  IssueStatus status,
) async {
  try {
    await ref.read(issuesApiProvider).updateIssueStatus(
          issueId: issue.id,
          statusApiValue: status.apiValue,
        );
    invalidateProjectTasksData(ref, projectId);
  } catch (e) {
    if (context.mounted) {
      showErrorSnackBar(context, e, fallback: 'Could not update status. Please try again.');
    }
  }
}

class _ProjectBanner extends StatelessWidget {
  const _ProjectBanner({required this.name, required this.onOverview});

  final String name;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Row(
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            IconButton(
              onPressed: onOverview,
              tooltip: 'Overview',
              icon: const Icon(Icons.info_outline_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectOverviewSection extends ConsumerWidget {
  const _ProjectOverviewSection({
    required this.project,
    required this.onViewMore,
  });

  final ProjectModel project;
  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final progressAsync = ref.watch(projectIssueProgressProvider(project.id));
    final membersAsync = ref.watch(projectMembersProvider(project.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Project Overview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onViewMore,
              child: const Text('View more'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          elevation: 0,
          child: InkWell(
            onTap: onViewMore,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(cs.surface, cs.primary, 0.10)!,
                    cs.surface,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.folder_open_rounded, color: cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (project.description ?? '').trim().isEmpty
                                  ? 'Tap to view project details'
                                  : project.description!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _OverviewChip(
                        icon: Icons.groups_rounded,
                        label: membersAsync.when(
                          data: (m) => '${m.length} members',
                          loading: () => 'Members…',
                          error: (_, __) => 'Members',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: progressAsync.when(
                          data: (p) => _ProgressStrip(
                            completed: p.completed,
                            total: p.total,
                            fraction: p.fraction,
                            percent: p.percent,
                          ),
                          loading: () => const _ProgressStrip(
                            completed: 0,
                            total: 0,
                            fraction: null,
                            percent: null,
                          ),
                          error: (_, __) => const _ProgressStrip(
                            completed: 0,
                            total: 0,
                            fraction: 0,
                            percent: 0,
                            error: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskOverviewSection extends StatelessWidget {
  const _TaskOverviewSection({
    required this.issues,
    required this.workflowColumns,
  });

  final List<IssueModel> issues;
  final List<IssueStatus> workflowColumns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    IssueStatus? byStatusOrNull(IssueStatus s) {
      for (final c in workflowColumns) {
        if (c == s) return c;
      }
      return null;
    }

    final tiles = <_TaskOverviewTileData>[
      if (byStatusOrNull(IssueStatus.toDo) != null)
        _TaskOverviewTileData(
          status: IssueStatus.toDo,
          title: 'To Do',
          color: const Color(0xFFE8E2FF), // pastel purple
          icon: Icons.checklist_rounded,
        ),
      if (byStatusOrNull(IssueStatus.inProgress) != null)
        _TaskOverviewTileData(
          status: IssueStatus.inProgress,
          title: 'In Process',
          color: const Color(0xFFE2F0FF), // pastel blue
          icon: Icons.play_circle_outline_rounded,
        ),
      if (byStatusOrNull(IssueStatus.inReview) != null)
        _TaskOverviewTileData(
          status: IssueStatus.inReview,
          title: 'Reviewing',
          color: const Color(0xFFFFE0EC), // pastel pink
          icon: Icons.rate_review_outlined,
        ),
      if (byStatusOrNull(IssueStatus.done) != null)
        _TaskOverviewTileData(
          status: IssueStatus.done,
          title: 'Complete',
          color: const Color(0xFFE3F7EA), // pastel green
          icon: Icons.verified_outlined,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Task Overview',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              // Fill remaining space with a 2x2 grid that stretches to the bottom.
              final tileHeight = ((c.maxHeight - 12) / 2).clamp(120.0, 10000.0);
              return GridView(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 180,
                ),
                children: [
                  for (final t in tiles.take(4))
                    _TaskOverviewTile(
                      data: t,
                      count: t.isPseudo ? 0 : issuesInColumn(issues, t.status).length,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskOverviewTileData {
  const _TaskOverviewTileData({
    required this.status,
    required this.title,
    required this.color,
    required this.icon,
    this.isPseudo = false,
  });

  final IssueStatus status;
  final String title;
  final Color color;
  final IconData icon;
  final bool isPseudo;
}

class _TaskOverviewTile extends ConsumerWidget {
  const _TaskOverviewTile({required this.data, required this.count});

  final _TaskOverviewTileData data;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedApi = ref.watch(boardStatusFilterProvider);
    final isSelected = !data.isPseudo && selectedApi == data.status.apiValue;
    final projectId = ref.watch(selectedProjectIdProvider) ?? '';
    final projectName = ref.watch(projectsListProvider).maybeWhen(
          data: (list) {
            for (final p in list) {
              if (p.id == projectId) return p.name;
            }
            return 'Project';
          },
          orElse: () => 'Project',
        );

    return Material(
      color: data.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: data.isPseudo
            ? null
            : () {
                ref.read(boardStatusFilterProvider.notifier).state = data.status.apiValue;
                if (projectId.isEmpty) return;
                context.push(
                  '/board/status',
                  extra: BoardStatusTasksArgs(
                    projectId: projectId,
                    statusApiValue: data.status.apiValue,
                    projectName: projectName,
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isSelected ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(data.icon, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.isPseudo ? '—' : '$count tasks',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewChip extends StatelessWidget {
  const _OverviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.completed,
    required this.total,
    required this.fraction,
    required this.percent,
    this.error = false,
  });

  final int completed;
  final int total;
  final double? fraction; // null => loading shimmer-like
  final int? percent; // null => loading
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final value = fraction;
    final showIndeterminate = value == null;

    final label = error
        ? 'Progress unavailable'
        : showIndeterminate
            ? 'Loading progress…'
            : total <= 0
                ? 'No tasks yet'
                : '$completed / $total • $percent%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: error ? cs.error : cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: showIndeterminate ? null : value!.clamp(0.0, 1.0),
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
