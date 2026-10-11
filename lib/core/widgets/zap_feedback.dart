import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador de carregamento padrão.
class ZapLoadingIndicator extends StatelessWidget {
  const ZapLoadingIndicator({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Carregando',
      child: SizedBox.square(
        dimension: size,
        child: const CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

enum ZapBannerKind { error, warning, info }

/// Faixa de mensagem com ícone, anunciada por leitores de tela.
class ZapBanner extends StatelessWidget {
  const ZapBanner({super.key, required this.message, this.kind = ZapBannerKind.error});

  final String message;
  final ZapBannerKind kind;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (kind) {
      ZapBannerKind.error => (AppColors.error, Icons.error_outline),
      ZapBannerKind.warning => (AppColors.warning, Icons.warning_amber_rounded),
      ZapBannerKind.info => (AppColors.accent, Icons.info_outline),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(120)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado de tela para recursos que pertencem a fases futuras do projeto.
/// Não finge funcionar: informa claramente o que ainda não existe.
class FeaturePendingView extends StatelessWidget {
  const FeaturePendingView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.phaseLabel,
  });

  final IconData icon;
  final String title;
  final String description;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                phaseLabel,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
