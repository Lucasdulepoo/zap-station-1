import 'package:flutter/material.dart';

import '../../core/widgets/zap_feedback.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contatos')),
      body: const FeaturePendingView(
        icon: Icons.contacts_outlined,
        title: 'Contatos em breve',
        description: 'A busca de contatos que já usam o ZAP STATION chega junto com as conversas, '
            'na Fase 3, com consentimento explícito para acessar sua agenda.',
        phaseLabel: 'Contatos · Fase 3',
      ),
    );
  }
}
