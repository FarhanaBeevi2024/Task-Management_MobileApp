import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/screens/access_control_screen.dart';
import '../../features/admin/screens/users_management_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/board/screens/board_screen.dart';
import '../../features/board/screens/board_status_tasks_screen.dart';
import '../../features/home/screens/main_shell_screen.dart';
import '../../features/milestones/screens/milestones_screen.dart';
import '../../features/onboarding/screens/intro_screen.dart';
import '../../features/projects/screens/project_overview_screen.dart';
import '../../features/work_items/screens/work_items_screen.dart';
import '../onboarding/onboarding_service.dart';
import 'auth_refresh_listenable.dart';

/// Central routing. Unauthenticated users go to `/login`.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefreshListenable(ref: ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final atLogin = state.matchedLocation == '/login';
      final atIntro = state.matchedLocation == '/intro';

      if (session == null) {
        final seen = await ref.read(onboardingServiceProvider).hasSeenIntro();
        if (!seen && !atIntro) return '/intro';
        if (seen && !atLogin) return '/login';
      }
      if (session != null && (atLogin || atIntro)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/intro',
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainShellScreen(),
      ),
      GoRoute(
        path: '/board',
        builder: (context, state) => const BoardScreen(showAppBarBack: true),
      ),
      GoRoute(
        path: '/board/status',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! BoardStatusTasksArgs) {
            return const Scaffold(body: Center(child: Text('Missing status args')));
          }
          return BoardStatusTasksScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UsersManagementScreen(),
      ),
      GoRoute(
        path: '/admin/access-control',
        builder: (context, state) => const AccessControlScreen(),
      ),
      GoRoute(
        path: '/work-items',
        builder: (context, state) => const WorkItemsScreen(),
      ),
      GoRoute(
        path: '/milestones',
        builder: (context, state) => const MilestonesScreen(),
      ),
      GoRoute(
        path: '/project-overview',
        builder: (context, state) => const ProjectOverviewScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.uri}')),
    ),
  );
});
