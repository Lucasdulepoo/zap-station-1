import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zap_station/core/theme/app_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // WCAG AA para texto normal: 4.5:1. Os valores esperados foram calculados fora do Flutter.
  const pairs = <String, (Color, Color)>{
    'texto principal / fundo': (AppColors.textPrimary, AppColors.background),
    'texto secundário / fundo': (AppColors.textSecondary, AppColors.background),
    'texto secundário / superfície': (AppColors.textSecondary, AppColors.surface),
    'texto secundário / superfície alta': (AppColors.textSecondary, AppColors.surfaceHigh),
    'texto atenuado / fundo': (AppColors.textMuted, AppColors.background),
    'texto atenuado / superfície': (AppColors.textMuted, AppColors.surface),
    'destaque / fundo': (AppColors.accent, AppColors.background),
    'destaque / superfície': (AppColors.accent, AppColors.surface),
    'texto sobre destaque': (AppColors.onAccent, AppColors.accent),
    'erro / fundo': (AppColors.error, AppColors.background),
    'sucesso / fundo': (AppColors.success, AppColors.background),
    'alerta / fundo': (AppColors.warning, AppColors.background),
  };

  pairs.forEach((name, pair) {
    test('contraste AA: $name', () {
      expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
    });
  });
}
