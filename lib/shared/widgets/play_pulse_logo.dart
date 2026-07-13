import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Logo **"Play Pulse"** VibeNime — segitiga play cyan di dalam lingkaran pulsa,
/// dengan echo arc magenta di luar. Vektor (CustomPainter) → tajam di segala
/// ukuran (16–1024px), tanpa aset raster. Dipakai di splash & branding.
///
/// [glow] = halo cyan lembut di belakang (mati-kan untuk pemakaian kecil/flat).
class PlayPulseLogo extends StatelessWidget {
  const PlayPulseLogo({required this.size, this.glow = true, super.key});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PlayPulsePainter(glow: glow)),
    );
  }
}

class _PlayPulsePainter extends CustomPainter {
  _PlayPulsePainter({required this.glow});

  final bool glow;

  static const _cyan = AppColors.primary; // #5DD3F0
  static const _magenta = Color(0xFFFF2E93);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = r * 0.055;

    // Halo cyan lembut di belakang.
    if (glow) {
      canvas.drawCircle(
        c,
        r * 0.62,
        Paint()
          ..color = _cyan.withValues(alpha: 0.22)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.28),
      );
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = _cyan;

    // Dua cincin pulsa cyan (dalam & luar).
    canvas.drawCircle(c, r * 0.60, ring..strokeWidth = stroke);
    canvas.drawCircle(c, r * 0.80, ring..strokeWidth = stroke * 0.8);

    // Echo arc magenta di kuadran kanan-atas (sekitar −80°..+30°).
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke * 1.1
      ..color = _magenta;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.71),
      -math.pi * 0.5, // mulai atas
      math.pi * 0.62, // ke kanan-bawah sedikit
      false,
      arc,
    );

    // Segitiga play cyan di tengah.
    final tri = r * 0.34;
    final path = Path()
      ..moveTo(c.dx - tri * 0.42, c.dy - tri * 0.62)
      ..lineTo(c.dx - tri * 0.42, c.dy + tri * 0.62)
      ..lineTo(c.dx + tri * 0.66, c.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = _cyan
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PlayPulsePainter old) => old.glow != glow;
}
