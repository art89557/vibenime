import 'package:flutter/services.dart';

/// Wrapper haptic feedback untuk konsistensi + testability.
///
/// **Kenapa wrapper?**
/// 1. **Consistency** — kita pakai pattern yang sama di seluruh app:
///    - [light] untuk button tap biasa
///    - [medium] untuk save / submit
///    - [heavy] untuk destructive (delete) atau error
///    - [selection] untuk picker / dropdown change
/// 2. **Testability** — di unit test, gampang di-mock (pure static methods).
/// 3. **Cross-platform** — Android & iOS handled by Flutter SDK; web/desktop
///    silently no-op.
///
/// Contoh penggunaan:
/// ```dart
/// FilledButton(
///   onPressed: () async {
///     await Haptic.medium();
///     await save();
///   },
///   child: Text('Save'),
/// )
/// ```
///
/// Bagian dari penerapan **Golden Rule 3 — Informative Feedback**.
class Haptic {
  Haptic._();

  /// Vibrasi tipis untuk button tap biasa.
  ///
  /// Ekuivalen native: iOS `UIImpactFeedbackGenerator.light`,
  /// Android `HapticFeedbackConstants.LIGHT`.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Vibrasi sedang untuk save / submit / konfirmasi penting.
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Vibrasi kuat untuk destructive action (delete) atau error.
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Vibrasi sangat halus untuk picker / dropdown / scroll-snap.
  static Future<void> selection() => HapticFeedback.selectionClick();
}
