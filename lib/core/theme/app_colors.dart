import 'package:flutter/material.dart';

/// Palet VibeNime v2 (post-redesign):
/// - Accent: cyan dingin (`#5DD3F0`) — replaces ungu-pink lama
/// - Surface: dark biru-keabuan (#0B0E14) — lebih editorial dari ungu
/// - Tone: editorial, premium, slightly mysterious
class AppColors {
  AppColors._();

  /// Primary cyan accent — dipakai untuk button utama, link, highlight.
  static const Color primary = Color(0xFF5DD3F0);

  /// Slightly darker variant untuk hover/pressed.
  static const Color primaryVariant = Color(0xFF3FB4D2);

  /// Subtle cyan glow — dipakai untuk border highlight pada chip aktif.
  static const Color primaryDim = Color(0xFF1B2A33);

  /// Secondary kept tapi jarang dipakai (untuk warna tambahan jika butuh).
  static const Color secondary = Color(0xFFFF8FA3);

  /// Surface gelap utama (background scaffold).
  static const Color surfaceDark = Color(0xFF0B0E14);

  /// Teks/ikon DI ATAS warna aksen terang (cyan/amber/medali) — selalu gelap
  /// di kedua theme. Pakai ini untuk label badge, foreground tombol primary,
  /// dll, JANGAN getter surface adaptif.
  static const Color onAccent = Color(0xFF0B0E14);

  /// Surface elevated (card, sheet, input).
  static const Color surfaceDarkElevated = Color(0xFF131822);

  /// Surface highest elevation (modal di atas card).
  static const Color surfaceDarkHigh = Color(0xFF1B2230);

  /// Surface light mode (jarang dipakai, default dark mode-first).
  static const Color surfaceLight = Color(0xFFF7F8FA);

  static const Color textOnDark = Color(0xFFEDF1F6);
  static const Color textOnDarkMuted = Color(0xFF8B95A5);
  static const Color textOnLight = Color(0xFF0B0E14);
  static const Color textOnLightMuted = Color(0xFF6B7280);

  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);

  /// Border subtle (1px) untuk card outline (dark theme).
  static const Color border = Color(0xFF1F2632);

  /// Border untuk light theme (lebih tipis).
  static const Color borderLight = Color(0xFFE5E7EB);

  // ─── Brightness-aware semantic getters ────────────────────────────────
  //
  // Pakai ini supaya widget auto-switch antara dark/light mode.
  // Sebelumnya banyak widget pakai `AppColors.surfaceDark` static — yang
  // tidak switch saat user pilih theme "Terang". Helper di bawah baca
  // `Theme.of(context).brightness` dan return color yang sesuai.
  //
  // **Pemakaian:**
  // ```dart
  // Container(color: AppColors.surface(context))
  // Text('...', style: TextStyle(color: AppColors.textPrimary(context)))
  // ```

  /// Background utama scaffold — adaptive.
  static Color surface(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? surfaceDark : surfaceLight;

  /// Background card / elevated container — adaptive.
  static Color surfaceElevated(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
      ? surfaceDarkElevated
      : Colors.white;

  /// Background tile high elevation (modal, dialog) — adaptive.
  static Color surfaceHigh(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
      ? surfaceDarkHigh
      : const Color(0xFFF1F3F7);

  /// Text utama (heading, body) — adaptive.
  static Color textPrimary(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? textOnDark : textOnLight;

  /// Text sekunder (subtitle, caption) — adaptive.
  static Color textMuted(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark
      ? textOnDarkMuted
      : textOnLightMuted;

  /// Border outline — adaptive.
  static Color borderColor(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? border : borderLight;

  /// Primary accent yang readable di kedua theme.
  /// Di light mode, cyan terang kurang contrast — pakai variant lebih gelap.
  static Color primaryAdaptive(BuildContext ctx) =>
      Theme.of(ctx).brightness == Brightness.dark ? primary : primaryVariant;
}
