import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_page_routes.dart';
import '../../../core/permissions/session_permissions.dart';
import '../../../core/widgets/app_snackbars.dart';
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
    show projectsListProvider, selectedProjectIdProvider;
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
      }
    });
    final columns = ref.watch(visibleBoardColumnsProvider);
    final issuesAsync = ref.watch(projectIssuesProvider);
    final projectsAsync = ref.watch(projectsListProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 520;

    final projectName = projectsAsync.whenOrNull(
      data: (List<ProjectModel> list) {
        final id = projectId;
        if (id == null || id.isEmpty) return null;
        for (final p in list) {
          if (p.id == id) return p.name;
        }
        return null;
      },
    );

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

    return Scaffold(
      backgroundColor: BoardColors.boardScaffoldBackground(context),
      appBar: showAppBarBack
          ? AppBar(
              backgroundColor: BoardColors.boardScaffoldBackground(context),
              elevation: 0,
              leading: const BackButton(),
              title: Text(projectName ?? 'Board'),
              actions: [
                IconButton(
                  tooltip: 'Overview',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => context.push('/project-overview'),
                ),
              ],
            )
          : null,
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
                if (!showAppBarBack && projectName != null && projectName.isNotEmpty)
                  _ProjectBanner(
                    name: projectName,
                    onOverview: () => context.push('/project-overview'),
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
                if (!showAppBarBack && projectName != null && projectName.isNotEmpty)
                  _ProjectBanner(
                    name: projectName,
                    onOverview: () => context.push('/project-overview'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: const _BoardFilters(),
                ),
                Expanded(
                  child: SlidableAutoCloseBehavior(
                    closeWhenOpened: true,
                    closeWhenTapped: true,
                    child: isCompact
                        ? _MobileBoardTabs(
                            projectId: projectId,
                            columns: columns,
                            all: all,
                            showAppBarBack: showAppBarBack,
                          )
                        : ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                            ),
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                              itemCount: columns.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, i) {
                                final column = columns[i];
                                final filteredAll = _applyBoardFilters(ref, all);
                                final list = issuesInColumn(filteredAll, column);
                                return KanbanColumn(
                                  width: _columnWidth,
                                  column: column,
                                  workflowColumns: columns,
                                  issues: list,
                                  projectId: projectId,
                                  onIssueTap: (issue) {
                                    Navigator.of(context).push<void>(
                                      AppPageRoutes.fadeSlide(
                                        IssueDetailScreen(issue: issue),
                                      ),
                                    );
                                  },
                                  onIssueActions: (issue) {
                                    showIssueTaskActionsSheet(
                                      context: context,
                                      issue: issue,
                                      projectId: projectId,
                                    );
                                  },
                                  onIssueEdit: (issue) async {
                                    final updated = await Navigator.of(context).push<IssueModel>(
                                      AppPageRoutes.fade(
                                        TaskFormScreen(
                                          projectId: projectId,
                                          issue: issue,
                                        ),
                                      ),
                                    );
                                    if (updated != null) {
                                      invalidateProjectTasksData(ref, projectId);
                                    }
                                  },
                                  onIssueSetStatus: (issue, status) =>
                                      _boardSetIssueStatus(context, ref, projectId, issue, status),
                                );
                              },
                            ),
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
    );
  }
}

class _MobileBoardTabs extends ConsumerWidget {
  const _MobileBoardTabs({
    required this.projectId,
    required this.columns,
    required this.all,
    required this.showAppBarBack,
  });

  final String projectId;
  final List<IssueStatus> columns;
  final List<IssueModel> all;
  final bool showAppBarBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final filteredAll = _applyBoardFilters(ref, all, ignoreStatusFilter: true);

    return DefaultTabController(
      key: ValueKey('mobile-tabs-${columns.map((c) => c.apiValue).join(",")}'),
      length: columns.length,
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              isScrollable: true,
              dividerColor: Colors.transparent,
              indicatorColor: scheme.primary,
              labelColor: scheme.onSurface,
              unselectedLabelColor: scheme.onSurfaceVariant,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              tabs: [
                for (final c in columns)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.label),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${issuesInColumn(filteredAll, c).length}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              children: [
                for (final c in columns)
                  _MobileStatusList(
                    projectId: projectId,
                    workflowColumns: columns,
                    column: c,
                    issues: issuesInColumn(filteredAll, c),
                    showAppBarBack: showAppBarBack,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileStatusList extends ConsumerWidget {
  const _MobileStatusList({
    required this.projectId,
    required this.workflowColumns,
    required this.column,
    required this.issues,
    required this.showAppBarBack,
  });

  final String projectId;
  final List<IssueStatus> workflowColumns;
  final IssueStatus column;
  final List<IssueModel> issues;
  final bool showAppBarBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (issues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No tasks in ${column.label}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: issues.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final issue = issues[i];
        return BoardIssueTile(
          slidableGroupTag: 'board-$projectId',
          issue: issue,
          workflowColumns: workflowColumns,
          onOpenDetail: () {
            Navigator.of(context).push<void>(
              AppPageRoutes.fadeSlide(
                IssueDetailScreen(issue: issue),
              ),
            );
          },
          onOpenActions: () {
            showIssueTaskActionsSheet(
              context: context,
              issue: issue,
              projectId: projectId,
            );
          },
          onEdit: () async {
            final updated = await Navigator.of(context).push<IssueModel>(
              AppPageRoutes.fade(
                TaskFormScreen(
                  projectId: projectId,
                  issue: issue,
                ),
              ),
            );
            if (updated != null) {
              invalidateProjectTasksData(ref, projectId);
            }
          },
          onSetStatus: (s) => _boardSetIssueStatus(context, ref, projectId, issue, s),
        );
      },
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
