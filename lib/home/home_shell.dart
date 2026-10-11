import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/application/session_controller.dart';
import '../core/widgets/zap_feedback.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: 'Conversas',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: 'Grupos',
    ),
    NavigationDestination(
      icon: Icon(Icons.call_outlined),
      selectedIcon: Icon(Icons.call),
      label: 'Chamadas',
    ),
    NavigationDestination(
      icon: Icon(Icons.contacts_outlined),
      selectedIcon: Icon(Icons.contacts),
      label: 'Contatos',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Ajustes',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final degraded = ref.watch(sessionProvider.select((s) => s.degraded));

    return Scaffold(
      body: Column(
        children: [
          if (degraded)
            SafeArea(
              bottom: false,
              child: const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: ZapBanner(
                  kind: ZapBannerKind.warning,
                  message: 'Sem conexão com o servidor. Algumas informações podem estar desatualizadas.',
                ),
              ),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
