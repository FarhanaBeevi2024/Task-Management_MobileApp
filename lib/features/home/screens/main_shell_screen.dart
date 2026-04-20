import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/workspace_bootstrap.dart';
import '../../../core/permissions/session_permissions.dart';
import '../../../core/providers/active_organization_provider.dart';
import '../../../core/widgets/app_background.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../calendar/screens/project_calendar_screen.dart';
import '../../projects/models/project_model.dart';
import '../../projects/providers/projects_providers.dart';
import '../../projects/screens/projects_list_screen.dart';

String _userInitials(UserModel u) {
  final fn = u.firstName?.trim() ?? '';
  final ln = u.lastName?.trim() ?? '';
  if (fn.isNotEmpty && ln.isNotEmpty) {
    return '${fn[0]}${ln[0]}'.toUpperCase();
  }
  if (fn.length >= 2) return fn.substring(0, 2).toUpperCase();
  if (fn.isNotEmpty) return fn[0].toUpperCase();
  if (ln.length >= 2) return ln.substring(0, 2).toUpperCase();
  if (ln.isNotEmpty) return ln[0].toUpperCase();
  final e = u.email.trim();
  if (e.length >= 2) return e.substring(0, 2).toUpperCase();
  if (e.isNotEmpty) return e[0].toUpperCase();
  return '?';
}

Widget _profileAvatarIcon(ColorScheme cs, {UserModel? user}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
    ),
    child: CircleAvatar(
      radius: 16,
      backgroundColor: Colors.transparent,
      child: user == null
          ? Icon(Icons.person_rounded, size: 18, color: cs.onPrimary)
          : Text(
              _userInitials(user),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onPrimary,
              ),
            ),
    ),
  );
}

/// Bottom navigation shell: swap body by tab index.
final mainShellIndexProvider = StateProvider<int>((ref) => 0);

Future<void> _signOutFromShell(WidgetRef ref) async {
  // All `ref` work must happen before `await signOut()`: sign-out notifies the
  // router and can dispose this shell immediately, invalidating [WidgetRef].
  ref.read(mainShellIndexProvider.notifier).state = 0;
  ref.read(accessTokenCacheProvider.notifier).state = null;
  ref.read(activeOrganizationIdProvider.notifier).state = null;
  ref.read(orgBootstrapUserIdProvider.notifier).state = null;
  ref.invalidate(sessionPermissionsProvider);
  ref.invalidate(currentUserProvider);
  ref.invalidate(projectsListProvider);
  await Supabase.instance.client.auth.signOut();
}

Future<void> _showProfileAccountMenu(BuildContext anchorContext, WidgetRef ref) async {
  final button = anchorContext.findRenderObject()! as RenderBox;
  final overlay = Navigator.of(anchorContext).overlay!.context.findRenderObject()! as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset.zero, ancestor: overlay),
      button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
    ),
    Offset.zero & overlay.size,
  );

  final choice = await showMenu<String>(
    context: anchorContext,
    position: position,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    items: <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Consumer(
          builder: (context, ref, _) {
            final userAsync = ref.watch(currentUserProvider);
            return userAsync.when(
              data: (user) {
                if (user == null) {
                  return const Text('No profile loaded.');
                }
                final theme = Theme.of(context);
                final cs = theme.colorScheme;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 240),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(
                height: 40,
                width: 200,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => const Text('Could not load profile.'),
            );
          },
        ),
      ),
      const PopupMenuDivider(height: 1),
      PopupMenuItem<String>(
        value: 'logout',
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Builder(
          builder: (context) {
            final cs = Theme.of(context).colorScheme;
            return Material(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).pop('logout'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Log out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  if (choice == 'logout') {
    await _signOutFromShell(ref);
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  static const _titles = ['Projects', 'Calendar', 'More'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureDefaultWorkspace(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(mainShellIndexProvider);
    final cs = Theme.of(context).colorScheme;

    void openProjectSearch() {
      showSearch<void>(
        context: context,
        delegate: _ProjectSearchDelegate(rootContext: context),
      );
    }

    final body = switch (index) {
      0 => const ProjectsListScreen(),
      1 => const ProjectCalendarScreen(),
      _ => const _MorePlaceholder(),
    };

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_titles[index]),
              if (index == 0)
                Text(
                  'Tap a project to open its board',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              if (index == 1)
                Text(
                  'Issues with due dates by month',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                if (index == 0) {
                  openProjectSearch();
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search is available on Projects tab.')),
                );
              },
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (profileBtnContext) {
                  return IconButton(
                    tooltip: 'Account',
                    onPressed: () => _showProfileAccountMenu(profileBtnContext, ref),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: ref.watch(currentUserProvider).when(
                      data: (u) => _profileAvatarIcon(cs, user: u),
                      loading: () => _profileAvatarIcon(cs, user: null),
                      error: (_, __) => _profileAvatarIcon(cs, user: null),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: body,
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) {
                ref.read(mainShellIndexProvider.notifier).state = i;
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder),
                  label: 'Projects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  selectedIcon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectSearchDelegate extends SearchDelegate<void> {
  _ProjectSearchDelegate({required this.rootContext})
      : super(searchFieldLabel: 'Search projects');

  final BuildContext rootContext;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear',
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }

  bool _match(ProjectModel p, String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return true;
    final name = p.name.toLowerCase();
    final key = (p.key ?? '').toLowerCase();
    final desc = (p.description ?? '').toLowerCase();
    return name.contains(t) || key.contains(t) || desc.contains(t);
  }

  void _openProject(ProjectModel p) {
    // Close search first, then navigate on the shell context.
    close(rootContext, null);
    Future.microtask(() {
      if (!rootContext.mounted) return;
      final c = ProviderScope.containerOf(rootContext, listen: false);
      c.read(selectedProjectIdProvider.notifier).state = p.id;
      GoRouter.of(rootContext).push('/board');
    });
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(projectsListProvider);
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e', textAlign: TextAlign.center),
            ),
          ),
          data: (projects) {
            final filtered = projects.where((p) => _match(p, query)).toList(growable: false);
            if (filtered.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    query.trim().isEmpty ? 'Type to search projects.' : 'No projects match “$query”.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = filtered[i];
                final subtitle = <String>[
                  if (p.key != null && p.key!.trim().isNotEmpty) p.key!.trim(),
                  if (p.description != null && p.description!.trim().isNotEmpty) p.description!.trim(),
                ].join(' • ');
                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _openProject(p),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MorePlaceholder extends ConsumerWidget {
  const _MorePlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final permsAsync = ref.watch(sessionPermissionsProvider);
    final canManageUsers = permsAsync.maybeWhen(
      data: (p) => p.global.canManageUsers,
      orElse: () => false,
    );
    final showMilestonesLink = permsAsync.maybeWhen(
      data: (p) => p.showMilestonesMenuLink,
      orElse: () => true,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        const SizedBox(height: 18),
        userAsync.when(
          data: (u) => u == null
              ? const SizedBox.shrink()
              : ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Your role'),
                  subtitle: Text(
                    u.role,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
          loading: () => const ListTile(
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text('Loading profile…'),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.extension_outlined),
                title: const Text('Work items'),
                subtitle: const Text('Tasks and issues assigned to you.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/work-items'),
              ),
              if (showMilestonesLink) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('Milestones'),
                  subtitle: const Text('Release milestones for your projects.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/milestones'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (canManageUsers) ...[
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Users'),
                  subtitle: const Text('Invite members and manage workspace roles.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/admin/users'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Access control'),
                  subtitle: const Text('Organization and project permissions by role.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/admin/access-control'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
