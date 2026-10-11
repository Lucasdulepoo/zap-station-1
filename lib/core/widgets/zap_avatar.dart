import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar com iniciais. Imagens remotas (Storage com URL assinada) entram na Fase 5.
class ZapAvatar extends StatelessWidget {
  const ZapAvatar({super.key, required this.name, this.radius = 24, this.isGroup = false});

  final String name;
  final double radius;
  final bool isGroup;

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first.substring(0, 1) + words.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceHigh,
        child: isGroup
            ? Icon(Icons.group, size: radius, color: AppColors.accent)
            : Text(
                initialsOf(name),
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.75,
                ),
              ),
      ),
    );
  }
}
