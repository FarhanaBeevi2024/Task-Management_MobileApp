import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_page_routes.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_footer_nav.dart';
import '../../../core/widgets/account_menu_button.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../issues/models/issue_model.dart';
import '../../issues/models/issue_status.dart';
import '../../issues/providers/issues_providers.dart';
import '../../issues/services/issues_api_service.dart';
import '../../issues/screens/issue_detail_screen.dart';
import '../../issues/screens/task_form_screen.dart';
import '../../issues/widgets/issue_task_actions_sheet.dart';
import '../providers/board_providers.dart';
import '../widgets/board_issue_tile.dart';

class BoardStatusTasksArgs {
  const BoardStatusTasksArgs({
    required this.projectId,
    required this.statusApiValue,
    required this.projectName,
  });

  final String projectId;
  final String statusApiValue;
  final String projectName;
}

class BoardStatusTasksScreen extends ConsumerStatefulWidget {
  const BoardStatusTasksScreen({super.key, required this.args});

  final BoardStatusTasksArgs args;

  @override
  ConsumerState<BoardStatusTasksScreen> createState() => _BoardStatusTasksScreenState();
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

class _BoardStatusTasksScreenState extends ConsumerState<BoardStatusTasksScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(boardSearchQueryProvider));
    _search.addListener(_syncToProvider);
  }

  void _syncToProvider() {
    final t = _search.text;
    if (t != ref.read(boardSearchQueryProvider)) {
      ref.read(boardSearchQueryProvider.notifier).state = t;
    }
  }

  @override
  void dispose() {
    _search.removeListener(_syncToProvider);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.args.projectId;
    final columns = ref.watch(visibleBoardColumnsProvider);
    final status = IssueStatus.fromApi(widget.args.statusApiValue);
    final effectiveStatus = columns.contains(status) ? status : columns.first;

    // Ensure provider state matches this screen (so search/filter helpers work).
    ref.listenManual<String>(boardStatusFilterProvider, (prev, next) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(boardStatusFilterProvider) != effectiveStatus.apiValue) {
        ref.read(boardStatusFilterProvider.notifier).state = effectiveStatus.apiValue;
      }
    });

    final allAsync = ref.watch(projectIssuesProvider);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        bottomNavigationBar: const AppFooterNav(),
        body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load tasks: $e')),
        data: (all) {
          final filteredAll = _applyBoardFilters(ref, all, ignoreStatusFilter: true);
          final list = issuesInColumn(filteredAll, effectiveStatus);

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${widget.args.projectName} • ${effectiveStatus.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const AccountMenuButton(),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search keyword',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _search.clear();
                        ref.read(boardSearchQueryProvider.notifier).state = '';
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyStateView(
                        title: 'No tasks',
                        message: 'No matching tasks found for this status.',
                        icon: Icons.inbox_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 96),
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final issue = list[i];
                          return BoardIssueTile(
                            slidableGroupTag: 'board-$projectId',
                            issue: issue,
                            workflowColumns: columns,
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
                      ),
              ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.of(context).push<IssueModel>(
            AppPageRoutes.fade(TaskFormScreen(projectId: projectId)),
          );
          if (saved != null) invalidateProjectTasksData(ref, projectId);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
      ),
    );
  }
}

