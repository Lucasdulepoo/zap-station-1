import 'package:flutter/material.dart';

import '../../core/widgets/zap_feedback.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grupos')),
      body: const FeaturePendingView(
        icon: Icons.groups_outlined,
        title: 'Grupos em breve',
        description: 'Criação de grupos, administradores e permissões entram na Fase 4. '
            'As regras de segurança já estão no banco de dados.',
        phaseLabel: 'Grupos · Fase 4',
      ),
    );
  }
}
