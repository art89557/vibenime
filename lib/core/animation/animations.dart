import 'package:flutter/widgets.dart';

/// Konstanta animasi yang dipakai konsisten di seluruh app.
///
/// Style: **Cinematic spring physics** — durations 220-520ms,
/// curve easeOutCubic (matches Spotify/Apple premium feel).
///
/// Pakai di:
/// - PressableScale tap feedback (short + smoothSpring)
/// - StaggeredItem entrance (medium + smoothSpring)
/// - Hero / page transitions (long + fastOutSlowIn)
/// - Lottie loop speed → keep default Lottie timing
class AppAnimations {
  AppAnimations._();

  /// 220ms — untuk tap feedback, button press, dropdown.
  static const Duration short = Duration(milliseconds: 220);

  /// 350ms — untuk tab switch, content fade, sheet slide.
  static const Duration medium = Duration(milliseconds: 350);

  /// 400ms — untuk hero transition, theme reveal, big page change.
  /// (Diturunkan dari 520ms supaya transisi terasa lebih snappy & clean.)
  static const Duration long = Duration(milliseconds: 400);

  /// Premium smooth feel — paling sering dipakai.
  static const Curve smoothSpring = Curves.easeOutCubic;

  /// Bouncy spring untuk "playful" moment (success checkmark, FAB bounce).
  static const Curve bouncySpring = Curves.elasticOut;

  /// Material standard untuk page transitions.
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;

  /// Snap-and-settle untuk seek bar release & modal sheet dismiss.
  static SpringDescription get gentleSpring =>
      const SpringDescription(mass: 1, stiffness: 100, damping: 15);

  /// Snappier spring untuk haptic-paired action (toggle, swipe).
  static SpringDescription get snappySpring =>
      const SpringDescription(mass: 0.6, stiffness: 180, damping: 14);

  /// Override in-app dari Settings ("Kurangi animasi"). Disinkronkan dari
  /// `appSettingsProvider` di root app. Default false.
  static bool reduceAnimationsOverride = false;

  /// Cek apakah animasi harus dikurangi — gabungan toggle in-app + OS-level
  /// "reduce animations" accessibility setting. Pakai di widget yang punya
  /// entrance/heavy animation.
  static bool reduceMotion(BuildContext context) {
    return reduceAnimationsOverride ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
  }
}
