import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/zap_feedback.dart';
import '../../core/widgets/zap_logo.dart';

/// Exibida enquanto a sessão é verificada. A verificação tem timeout
/// (SessionController), então esta tela nunca bloqueia indefinidamente.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZapMark(size: 96),
            SizedBox(height: 24),
            ZapWordmark(size: 26),
            SizedBox(height: 40),
            ZapLoadingIndicator(),
            SizedBox(height: 16),
            Text('Iniciando…', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
