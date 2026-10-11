import 'package:flutter/material.dart';

/// Paleta ZAP STATION. Os pares de contraste usados no app são verificados em
/// test/core/contrast_test.dart (WCAG AA, 4.5:1).
abstract final class AppColors {
  static const Color background = Color(0xFF0B0D10); // preto grafite
  static const Color surface = Color(0xFF14181D);
  static const Color surfaceHigh = Color(0xFF1C222A);
  static const Color outline = Color(0xFF2A323C);

  static const Color accent = Color(0xFF00D1FF); // ciano elétrico
  static const Color onAccent = Color(0xFF001A22);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA6B0BC);
  static const Color textMuted = Color(0xFF7B8794);

  static const Color success = Color(0xFF2FBF71);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF6B7A);
}
