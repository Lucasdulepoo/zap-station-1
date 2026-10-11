import 'package:flutter/material.dart';

import '../../core/widgets/zap_feedback.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chamadas')),
      body: const FeaturePendingView(
        icon: Icons.call_outlined,
        title: 'Chamadas em breve',
        description: 'Chamadas de voz e vídeo (WebRTC com LiveKit) entram na Fase 7 e exigem '
            'um servidor de mídia configurado. O histórico aparecerá aqui.',
        phaseLabel: 'Chamadas · Fase 7',
      ),
    );
  }
}
