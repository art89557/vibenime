import 'package:flutter/material.dart';

import '../../core/animation/animations.dart';
import '../../core/utils/haptic_helper.dart';

/// Wrap widget dengan scale-down feedback saat ditekan.
///
/// Pattern Apple/Spotify: tap → shrink instant (95-98%) → release →
/// snap kembali ke 1.0 dengan spring. Bikin button "alive" tanpa beat
/// material ripple default.
///
/// Usage:
/// ```dart
/// PressableScale(
///   onTap: () => doSomething(),
///   child: Container(... my custom button ...),
/// )
/// ```
///
/// **Accessibility**: tap target area TETAP full size (scale visual only,
/// hit-test pakai original bounds via `behavior: HitTestBehavior.opaque`).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.96,
    this.hapticOnTap = true,
    this.duration,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale value saat ditekan (1.0 = no scale, 0.95 = 5% shrink).
  final double scaleDown;

  /// Trigger selectionClick haptic saat tap up. Default true.
  final bool hapticOnTap;

  /// Override duration (default 120ms — sangat snappy).
  final Duration? duration;

  /// Set false untuk disable interaction (tampilan tetap full size).
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  // Eager init di initState — JANGAN `late final` dengan initializer lazy:
  // saat reduce-motion ON build tak pernah akses _controller, lalu dispose()
  // jadi akses pertama → bikin AnimationController saat teardown →
  // "Looking up a deactivated widget's ancestor is unsafe".
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration ?? const Duration(milliseconds: 120),
      value: 1.0,
      lowerBound: widget.scaleDown,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _controller.animateTo(
      widget.scaleDown,
      duration: const Duration(milliseconds: 80),
      curve: AppAnimations.smoothSpring,
    );
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 180),
      curve: AppAnimations.smoothSpring,
    );
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    _controller.animateTo(
      1.0,
      duration: const Duration(milliseconds: 220),
      curve: AppAnimations.smoothSpring,
    );
  }

  void _handleTap() {
    if (!widget.enabled || widget.onTap == null) return;
    if (widget.hapticOnTap) Haptic.selection();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduce-motion setting di OS — kalau aktif, skip animation.
    if (AppAnimations.reduceMotion(context)) {
      return GestureDetector(
        onTap: widget.enabled ? _handleTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _handleTap,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}
