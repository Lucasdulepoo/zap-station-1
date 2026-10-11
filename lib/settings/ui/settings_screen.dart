import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/zap_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você precisará confirmar seu número por SMS para entrar de novo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).signOut();
      await ref.read(sessionProvider.notifier).refresh();
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final backend = ref.watch(backendStatusProvider);
    final config = ref.watch(appConfigProvider);
    final phone = ref.watch(authRepositoryProvider).currentPhone;

    final name = profile.valueOrNull?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: ZapAvatar(name: name.isEmpty ? '?' : name, radius: 28),
            title: Text(
              name.isEmpty ? 'Sem nome' : name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            subtitle: Text(
              phone == null || phone.isEmpty ? 'Telefone indisponível' : '+${phone.replaceFirst('+', '')}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              backend.isReady ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: backend.isReady ? AppColors.success : AppColors.warning,
            ),
            title: const Text('Servidor'),
            subtitle: Text(
              backend.userMessage,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão'),
            subtitle: Text(
              '$kAppVersion · ${config.environment}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Privacidade'),
            subtitle: Text(
              'Última visualização e confirmação de leitura: Fase 3',
              style: TextStyle(color: AppColors.textMuted),
            ),
            enabled: false,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sair', style: TextStyle(color: AppColors.error)),
            onTap: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
    );
  }
}
