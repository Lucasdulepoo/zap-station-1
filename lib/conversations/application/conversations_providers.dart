import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conversation_summary.dart';

/// Lista de conversas do usuário.
///
/// FASE 1: ainda não há envio/recebimento de mensagens, então não existem conversas
/// para listar e o provider devolve uma lista vazia de verdade (não há dados de exemplo
/// no app). A Fase 3 troca esta implementação por uma consulta ao Supabase
/// (conversation_members + conversations + última mensagem) com Realtime.
final conversationSummariesProvider = Provider<List<ConversationSummary>>(
  (ref) => const <ConversationSummary>[],
);

/// Filtra por título ou prévia, sem diferenciar maiúsculas/minúsculas.
List<ConversationSummary> filterConversations(List<ConversationSummary> all, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where((c) =>
          c.title.toLowerCase().contains(q) || c.lastMessagePreview.toLowerCase().contains(q))
      .toList();
}
