import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/zap_avatar.dart';
import '../domain/conversation_summary.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.now,
    this.onTap,
  });

  final ConversationSummary conversation;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final time = formatActivityTime(conversation.lastActivityAt, now);

    return Semantics(
      container: true,
      label: '${conversation.title}. ${conversation.lastMessagePreview}. $time.'
          '${unread > 0 ? ' $unread não lidas.' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                ZapAvatar(
                  name: conversation.title,
                  isGroup: conversation.isGroup,
                  radius: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (conversation.lastMessageState != null) ...[
                            _StateIcon(state: conversation.lastMessageState!),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              conversation.lastMessagePreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: unread > 0 ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (unread > 0) _UnreadBadge(count: unread) else const SizedBox(height: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.state});

  final MessageDeliveryState state;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (state) {
      MessageDeliveryState.sending => (Icons.schedule, AppColors.textMuted),
      MessageDeliveryState.sent => (Icons.done, AppColors.textSecondary),
      MessageDeliveryState.delivered => (Icons.done_all, AppColors.textSecondary),
      MessageDeliveryState.read => (Icons.done_all, AppColors.accent),
      MessageDeliveryState.failed => (Icons.error_outline, AppColors.error),
    };
    return Icon(icon, size: 16, color: color);
  }
}
