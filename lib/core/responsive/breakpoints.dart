import 'package:flutter/material.dart';

/// Breakpoint scheme VibeNime — material-inspired tapi disesuaikan.
///
/// | Range             | Tier      | Layout pattern                  |
/// |-------------------|-----------|----------------------------------|
/// | < 600px           | mobile    | Single col, BottomNav            |
/// | 600 - 1024px      | tablet    | 2-col grid, NavigationRail       |
/// | 1024 - 1440px     | desktop   | 3-col grid + sidebar             |
/// | >= 1440px         | desktopLg | 4-col grid + sidebar + content max-width |
enum DeviceTier { mobile, tablet, desktop, desktopLg }

class Breakpoints {
  Breakpoints._();

  static const double tablet = 600;
  static const double desktop = 1024;
  static const double desktopLg = 1440;

  /// Resolve [DeviceTier] dari MediaQuery width.
  static DeviceTier of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < tablet) return DeviceTier.mobile;
    if (w < desktop) return DeviceTier.tablet;
    if (w < desktopLg) return DeviceTier.desktop;
    return DeviceTier.desktopLg;
  }

  /// Width-only check (untuk widget yang tidak butuh BuildContext).
  static DeviceTier ofWidth(double width) {
    if (width < tablet) return DeviceTier.mobile;
    if (width < desktop) return DeviceTier.tablet;
    if (width < desktopLg) return DeviceTier.desktop;
    return DeviceTier.desktopLg;
  }

  /// Pilih value berdasarkan tier. Mobile = required, lainnya fallback ke mobile.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? desktopLg,
  }) {
    switch (of(context)) {
      case DeviceTier.mobile:
        return mobile;
      case DeviceTier.tablet:
        return tablet ?? mobile;
      case DeviceTier.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceTier.desktopLg:
        return desktopLg ?? desktop ?? tablet ?? mobile;
    }
  }

  /// Jumlah kolom default untuk grid (poster card list).
  static int columnsFor(BuildContext context) {
    return value(context, mobile: 3, tablet: 4, desktop: 6, desktopLg: 8);
  }

  /// Max width content card untuk full-screen list di desktop —
  /// supaya tidak stretch terlalu lebar (uncomfortable scroll).
  static double maxContentWidth(BuildContext context) {
    return value(
      context,
      mobile: double.infinity,
      tablet: 900,
      desktop: 1200,
      desktopLg: 1440,
    );
  }

  /// True kalau platform di-asumsikan butuh BottomNav (mobile portrait).
  static bool useBottomNav(BuildContext context) =>
      of(context) == DeviceTier.mobile;

  /// True kalau cocok pakai NavigationRail (tablet, atau desktop kalau prefer compact).
  static bool useNavigationRail(BuildContext context) {
    final tier = of(context);
    return tier == DeviceTier.tablet;
  }

  /// True kalau cocok pakai sidebar drawer permanent (desktop+).
  static bool useSidebar(BuildContext context) {
    final tier = of(context);
    return tier == DeviceTier.desktop || tier == DeviceTier.desktopLg;
  }
}

/// Extension shorthand: `context.tier`, `context.isMobile`, dll.
extension BreakpointContext on BuildContext {
  DeviceTier get tier => Breakpoints.of(this);
  bool get isMobile => tier == DeviceTier.mobile;
  bool get isTablet => tier == DeviceTier.tablet;
  bool get isDesktop =>
      tier == DeviceTier.desktop || tier == DeviceTier.desktopLg;
}
