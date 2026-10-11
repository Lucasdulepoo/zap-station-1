import 'package:flutter/material.dart';

enum ZapButtonVariant { primary, secondary }

/// Botão padrão do app. Com `loading: true` fica desabilitado e mostra progresso.
/// `onPressed: null` renderiza o botão desabilitado (usado para funções de fases futuras).
class ZapButton extends StatelessWidget {
  const ZapButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.variant = ZapButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final ZapButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? effective = loading ? null : onPressed;

    final Widget child = loading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final button = switch (variant) {
      ZapButtonVariant.primary => FilledButton(onPressed: effective, child: child),
      ZapButtonVariant.secondary => OutlinedButton(onPressed: effective, child: child),
    };

    return Semantics(
      button: true,
      enabled: effective != null,
      label: loading ? '$label, carregando' : label,
      excludeSemantics: true,
      child: button,
    );
  }
}
