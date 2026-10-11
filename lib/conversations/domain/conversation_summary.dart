/// Estado de envio da última mensagem, do ponto de vista de quem enviou.
enum MessageDeliveryState { sending, sent, delivered, read, failed }

/// Linha da lista de conversas.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessagePreview,
    required this.lastActivityAt,
    this.isGroup = false,
    this.unreadCount = 0,
    this.lastMessageState,
  });

  final String id;
  final String title;
  final String lastMessagePreview;
  final DateTime lastActivityAt;
  final bool isGroup;
  final int unreadCount;

  /// Preenchido apenas quando a última mensagem foi enviada pelo usuário atual.
  final MessageDeliveryState? lastMessageState;
}
