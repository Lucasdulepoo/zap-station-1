import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marca ZAP STATION: hexágono com raio, desenhada em código (original, sem assets de terceiros).
/// A geometria é a mesma de assets/brand/zap_station_logo.svg.
class ZapMark extends StatelessWidget {
  const ZapMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logotipo ZAP STATION',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ZapMarkPainter()),
      ),
    );
  }
}

class _ZapMarkPainter extends CustomPainter {
  // Pontos normalizados (0..1).
  static const List<Offset> _bolt = [
    Offset(0.58, 0.14),
    Offset(0.31, 0.54),
    Offset(0.48, 0.54),
    Offset(0.42, 0.86),
    Offset(0.69, 0.45),
    Offset(0.52, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    final hex = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (-90 + 60 * i) * math.pi / 180;
      final point = Offset(
        s * 0.5 + s * 0.46 * math.cos(angle),
        s * 0.5 + s * 0.46 * math.sin(angle),
      );
      if (i == 0) {
        hex.moveTo(point.dx, point.dy);
      } else {
        hex.lineTo(point.dx, point.dy);
      }
    }
    hex.close();

    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.accent,
    );

    final bolt = Path()..moveTo(_bolt.first.dx * s, _bolt.first.dy * s);
    for (final point in _bolt.skip(1)) {
      bolt.lineTo(point.dx * s, point.dy * s);
    }
    bolt.close();

    canvas.drawPath(bolt, Paint()..color = AppColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Apenas o texto "ZAP STATION" (logotipo tipográfico).
class ZapWordmark extends StatelessWidget {
  const ZapWordmark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ZAP STATION',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'ZAP ',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: size,
                  letterSpacing: size * 0.12,
                ),
              ),
              TextSpan(
                text: 'STATION',
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  color: AppColors.accent,
                  fontSize: size,
                  letterSpacing: size * 0.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marca + texto lado a lado.
class ZapLogo extends StatelessWidget {
  const ZapLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ZapMark(size: size * 1.4),
        SizedBox(width: size * 0.4),
        ZapWordmark(size: size),
      ],
    );
  }
}
