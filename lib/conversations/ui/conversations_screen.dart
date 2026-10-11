import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/zap_feedback.dart';
import '../../core/widgets/zap_logo.dart';
import '../../core/widgets/zap_text_field.dart';
import '../application/conversations_providers.dart';
import 'conversation_tile.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(conversationSummariesProvider);
    final visible = filterConversations(all, _query);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const ZapLogo(size: 20)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: ZapTextField(
              label: 'Buscar conversas',
              prefix: const Icon(Icons.search),
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: all.isEmpty
                ? const FeaturePendingView(
                    icon: Icons.chat_bubble_outline,
                    title: 'Nenhuma conversa ainda',
                    description: 'O envio e o recebimento de mensagens chegam na Fase 3 do projeto. '
                        'Por enquanto sua conta, seu perfil e a navegação já estão ativos.',
                    phaseLabel: 'Mensagens · Fase 3',
                  )
                : visible.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma conversa encontrada.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, i) =>
                            ConversationTile(conversation: visible[i], now: now),
                      ),
          ),
        ],
      ),
      // Desabilitado de propósito: abrir uma conversa depende da Fase 3.
      floatingActionButton: const FloatingActionButton.extended(
        onPressed: null,
        tooltip: 'Disponível na Fase 3',
        backgroundColor: AppColors.surfaceHigh,
        foregroundColor: AppColors.textMuted,
        icon: Icon(Icons.edit_outlined),
        label: Text('Nova conversa · Fase 3'),
      ),
    );
  }
}
