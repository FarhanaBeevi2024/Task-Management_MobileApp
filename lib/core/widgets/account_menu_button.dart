import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/workspace_bootstrap.dart';
import '../providers/active_organization_provider.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../permissions/session_permissions.dart';
import '../../features/projects/providers/projects_providers.dart';

String _userInitials(UserModel u) {
  final fn = u.firstName?.trim() ?? '';
  final ln = u.lastName?.trim() ?? '';
  if (fn.isNotEmpty && ln.isNotEmpty) return '${fn[0]}${ln[0]}'.toUpperCase();
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

Future<void> _signOutEverywhere(WidgetRef ref) async {
  // Do all provider work before awaiting signOut (router may dispose widgets).
  ref.read(accessTokenCacheProvider.notifier).state = null;
  ref.read(activeOrganizationIdProvider.notifier).state = null;
  ref.read(orgBootstrapUserIdProvider.notifier).state = null;
  ref.invalidate(sessionPermissionsProvider);
  ref.invalidate(currentUserProvider);
  ref.invalidate(projectsListProvider);
  await Supabase.instance.client.auth.signOut();
}

Future<void> _showAccountMenu(BuildContext anchorContext, WidgetRef ref) async {
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
                if (user == null) return const Text('No profile loaded.');
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
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
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
                      style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
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
    await _signOutEverywhere(ref);
  }
}

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Builder(
      builder: (anchorContext) {
        return IconButton(
          tooltip: 'Account',
          onPressed: () => _showAccountMenu(anchorContext, ref),
          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: ref.watch(currentUserProvider).when(
                data: (u) => _profileAvatarIcon(cs, user: u),
                loading: () => _profileAvatarIcon(cs, user: null),
                error: (_, __) => _profileAvatarIcon(cs, user: null),
              ),
        );
      },
    );
  }
}

