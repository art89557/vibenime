import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Logo **"Play Pulse"** VibeNime — segitiga play cyan di dalam cincin dua-warna
/// (mayoritas cyan + potongan magenta di atas sebagai "echo/vibe"), dgn cincin
/// echo tipis di luar. Vektor (CustomPainter) → tajam di segala ukuran, tanpa
/// aset raster. Dipakai di splash & launcher icon.
///
/// [glow] = halo cyan lembut (aktifkan untuk splash; matikan untuk icon supaya
/// tidak "bleed" ke tepi).
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

    // Halo cyan lembut (opsional).
    if (glow) {
      canvas.drawCircle(
        c,
        r * 0.58,
        Paint()
          ..color = _cyan.withValues(alpha: 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.26),
      );
    }

    // Cincin echo tipis di luar.
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.022
        ..color = _cyan.withValues(alpha: 0.35),
    );

    // Cincin utama dua-warna: magenta mengisi celah di atas, cyan sisanya.
    final rMain = r * 0.62;
    final rect = Rect.fromCircle(center: c, radius: rMain);
    const top = -math.pi / 2;
    const magHalf = 0.18 * math.pi; // setengah lebar potongan magenta
    const gap = 0.05 * math.pi; // jeda antar warna (round cap tak bertumpuk)

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.085;

    // Magenta: terpusat di atas.
    canvas.drawArc(
      rect,
      top - magHalf,
      magHalf * 2,
      false,
      ringPaint..color = _magenta,
    );
    // Cyan: sisa lingkaran (dgn jeda di kedua ujung magenta).
    canvas.drawArc(
      rect,
      top + magHalf + gap,
      2 * math.pi - magHalf * 2 - gap * 2,
      false,
      ringPaint..color = _cyan,
    );

    // Segitiga play cyan, di-center optis (sedikit ke kiri) + sudut membulat.
    final t = r * 0.30;
    final tri = Path()
      ..moveTo(c.dx - t * 0.34, c.dy - t * 0.58)
      ..lineTo(c.dx - t * 0.34, c.dy + t * 0.58)
      ..lineTo(c.dx + t * 0.64, c.dy)
      ..close();
    final triPaint = Paint()
      ..color = _cyan
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(tri, triPaint..style = PaintingStyle.fill)
      ..drawPath(
        tri,
        triPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.05,
      );
  }

  @override
  bool shouldRepaint(_PlayPulsePainter old) => old.glow != glow;
}
