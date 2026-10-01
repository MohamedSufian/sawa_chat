import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/calls/presentation/call_screen.dart';
import '../../features/calls/presentation/calls_screen.dart';
import '../../features/chats/presentation/chat_screen.dart';
import '../../features/chats/presentation/chats_screen.dart';
import '../../features/chats/presentation/search_users_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/group_info_screen.dart';
import '../../features/groups/presentation/select_members_screen.dart';
import '../../features/home/presentation/home_shell.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/profile/presentation/profile_setup_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../widgets/common.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Bridges session changes into go_router's refreshListenable.
  final refresh = ValueNotifier(ref.read(sessionControllerProvider).status);
  ref.listen(sessionControllerProvider, (_, next) => refresh.value = next.status);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final inAuth = location.startsWith('/auth');

      return switch (ref.read(sessionControllerProvider).status) {
        SessionStatus.loading || SessionStatus.error => location == Routes.splash ? null : Routes.splash,
        SessionStatus.signedOut => inAuth ? null : Routes.phone,
        SessionStatus.needsProfile => location == Routes.setup ? null : Routes.setup,
        SessionStatus.ready => (inAuth || location == Routes.splash || location == Routes.setup) ? Routes.chats : null,
      };
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.phone, builder: (_, _) => const PhoneScreen()),
      GoRoute(
        path: Routes.otp,
        redirect: (_, state) => state.extra is String ? null : Routes.phone,
        builder: (_, state) => OtpScreen(phone: state.extra! as String),
      ),
      GoRoute(path: Routes.setup, builder: (_, _) => const ProfileSetupScreen()),
      // Full-screen routes above the bottom navigation.
      GoRoute(path: Routes.search, builder: (_, _) => const SearchUsersScreen()),
      GoRoute(
        path: Routes.chatPattern,
        builder: (_, state) => ChatScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(path: Routes.call, builder: (_, _) => const CallScreen()),
      GoRoute(
        path: Routes.groupInfoPattern,
        builder: (_, state) => GroupInfoScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: Routes.newGroup,
        builder: (context, _) => SelectMembersScreen(
          title: context.l10n.newGroup,
          onDone: (ctx, people) => ctx.push(Routes.newGroupDetails, extra: people),
        ),
      ),
      GoRoute(
        path: Routes.newGroupDetails,
        redirect: (_, state) => state.extra is List<Profile> ? null : Routes.newGroup,
        builder: (_, state) => CreateGroupScreen(members: state.extra! as List<Profile>),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.chats, builder: (_, _) => const ChatsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.calls, builder: (_, _) => const CallsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen())],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
