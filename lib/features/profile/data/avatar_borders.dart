import 'package:flutter/material.dart';

/// Pre-set avatar border colors — user pilih di EditProfile sebagai
/// decorative ring around avatar.
///
/// Disimpan di user_metadata.avatar_border sebagai string code.
enum AvatarBorderStyle {
  none('none', 'Tanpa Border', null, null),
  cyan('cyan', 'Cyan', Color(0xFF5DD3F0), null),
  gold('gold', 'Gold', Color(0xFFFFD700), null),
  rose('rose', 'Rose', Color(0xFFFF8FA3), null),
  emerald('emerald', 'Emerald', Color(0xFF4ADE80), null),
  violet('violet', 'Violet', Color(0xFFA78BFA), null),
  sunset('sunset', 'Sunset', null, [
    Color(0xFFFFD700),
    Color(0xFFFF8FA3),
    Color(0xFFA78BFA),
  ]);

  const AvatarBorderStyle(
    this.code,
    this.label,
    this.solidColor,
    this.gradientColors,
  );

  /// Code disimpan di user_metadata.avatar_border.
  final String code;

  /// Display label di picker.
  final String label;

  /// Single color border (atau null kalau gradient).
  final Color? solidColor;

  /// Gradient stops untuk multi-color border (animated).
  final List<Color>? gradientColors;

  /// Parse dari user_metadata code → enum value.
  static AvatarBorderStyle fromCode(String? code) {
    for (final s in AvatarBorderStyle.values) {
      if (s.code == code) return s;
    }
    return AvatarBorderStyle.none;
  }

  /// Convenience: dapatkan border decoration untuk avatar circle.
  /// Return null kalau style = none (avatar plain).
  Border? get border {
    if (solidColor != null) {
      return Border.all(color: solidColor!, width: 3);
    }
    // Sunset (gradient) — Flutter Border tidak support gradient native,
    // jadi callsite harus pakai Container dengan BoxDecoration.gradient.
    return null;
  }

  /// Decoration untuk avatar dengan gradient sweep (untuk sunset).
  /// Single-color borders pakai `.border` (lebih efisien).
  BoxDecoration? get sweepDecoration {
    if (gradientColors == null) return null;
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: SweepGradient(
        colors: [...gradientColors!, gradientColors!.first],
      ),
    );
  }
}
