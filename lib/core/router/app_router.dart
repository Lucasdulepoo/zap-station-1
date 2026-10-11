import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/session_controller.dart';
import '../../auth/domain/phone_number.dart';
import '../../auth/ui/otp_screen.dart';
import '../../auth/ui/phone_screen.dart';
import '../../auth/ui/profile_setup_screen.dart';
import '../../auth/ui/splash_screen.dart';
import '../../calls/ui/calls_screen.dart';
import '../../contacts/ui/contacts_screen.dart';
import '../../conversations/ui/conversations_screen.dart';
import '../../groups/ui/groups_screen.dart';
import '../../home/home_shell.dart';
import '../../settings/ui/settings_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const profile = '/auth/profile';
  static const conversations = '/home/conversations';
  static const groups = '/home/groups';
  static const calls = '/home/calls';
  static const contacts = '/home/contacts';
  static const settings = '/home/settings';
}

/// Regra de redirecionamento pura (testável sem Flutter): dado o estado da sessão
/// e a rota atual, devolve a rota para onde ir, ou null para ficar.
String? resolveRedirect(SessionStatus status, String location) {
  switch (status) {
    case SessionStatus.initializing:
      return location == Routes.splash ? null : Routes.splash;
    case SessionStatus.signedOut:
      final inAuthFlow = location == Routes.phone || location == Routes.otp;
      return inAuthFlow ? null : Routes.phone;
    case SessionStatus.needsProfile:
      return location == Routes.profile ? null : Routes.profile;
    case SessionStatus.ready:
      final inPreHome = location == Routes.splash || location.startsWith('/auth');
      return inPreHome ? Routes.conversations : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<SessionState>(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        resolveRedirect(ref.read(sessionProvider).status, state.matchedLocation),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.phone, builder: (_, __) => const PhoneScreen()),
      GoRoute(
        path: Routes.otp,
        // Sem o número (ex.: processo recriado) não há o que verificar: volta ao início.
        redirect: (_, state) => state.extra is PhoneNumber ? null : Routes.phone,
        builder: (_, state) => OtpScreen(phone: state.extra! as PhoneNumber),
      ),
      GoRoute(path: Routes.profile, builder: (_, __) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.conversations, builder: (_, __) => const ConversationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.groups, builder: (_, __) => const GroupsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.calls, builder: (_, __) => const CallsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.contacts, builder: (_, __) => const ContactsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.settings, builder: (_, __) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Página não encontrada.')),
    ),
  );

  ref.onDispose(router.dispose);
  return router;
});
