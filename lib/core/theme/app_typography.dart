import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system VibeNime — 2 font pasangan + 1 mono.
///
/// - **Display** (Playfair Display italic) — heading hero, brand, section
/// - **Body** (Roboto) — paragraf, list, label, button
/// - **Mono** (JetBrains Mono) — angka stat, progress label, code
///
/// Pakai instead of `GoogleFonts.playfairDisplay` / `GoogleFonts.roboto` /
/// `GoogleFonts.roboto`. Konsisten + 1 sumber kebenaran untuk font.
///
/// Usage:
/// ```dart
/// Text('VibeNime', style: AppTypography.display(size: 32))
/// Text('Hello world', style: AppTypography.body(size: 14))
/// Text('12.5K', style: AppTypography.mono(size: 11))
/// ```
class AppTypography {
  AppTypography._();

  /// Heading display — Playfair Display italic.
  /// Untuk: hero title, section header, app brand "VibeNime".
  static TextStyle display({
    double size = 32,
    Color? color,
    FontWeight weight = FontWeight.w600,
    double height = 1.1,
  }) => GoogleFonts.playfairDisplay(
    fontSize: size,
    fontStyle: FontStyle.italic,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Body text — Roboto sans-serif.
  /// Untuk: paragraf, list item, label, button, input.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) => GoogleFonts.roboto(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Mono — JetBrains Mono untuk angka & code.
  /// Untuk: progress "EP 5/12", stat number, timestamp.
  static TextStyle mono({
    double size = 11,
    Color? color,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0.5,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}
