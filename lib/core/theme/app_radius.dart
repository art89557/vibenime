import 'package:flutter/widgets.dart';

/// Token border-radius VibeNime — konsolidasi 12 nilai ad-hoc (2,4,6,7,8,10,
/// 12,14,16,20,24,999) jadi 1 skala konsisten. Bikin sudut UI seragam ("clean").
///
/// Pemetaan migrasi: 2→tiny · 6/7→sm · 10/14→md · 24→xl.
class AppRadius {
  AppRadius._();

  /// 4 — hairline (progress bar tipis), detail kecil.
  static const double tiny = 4;

  /// 8 — chip, thumbnail kecil, badge, tombol kecil.
  static const double sm = 8;

  /// 12 — kartu standar, tile, input, sheet kecil.
  static const double md = 12;

  /// 16 — kartu besar, hero, bottom sheet.
  static const double lg = 16;

  /// 20 — kontainer besar, modal, pill nav.
  static const double xl = 20;

  /// 999 — pill / fully-rounded (avatar, badge bulat).
  static const double pill = 999;

  // BorderRadius helpers (semua sisi) — pakai untuk const decoration.
  static const BorderRadius brTiny = BorderRadius.all(Radius.circular(tiny));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}
