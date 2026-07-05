import 'package:flutter/material.dart';

import '../../core/animation/animations.dart';

/// Item dengan fade+slide entrance ber-delay sesuai posisi index.
///
/// Pattern: saat list/grid pertama tampil, item-item masuk satu-per-satu
/// dengan delay (index * stagger) — mata user "melihat wave".
///
/// Cap total delay: kalau index tinggi, delay di-clamp supaya tidak nunggu
/// terlalu lama (mis. item ke-20 jangan delay 1.2s).
///
/// Usage:
/// ```dart
/// ListView.builder(
///   itemBuilder: (ctx, i) => StaggeredItem(
///     index: i,
///     child: AnimeCard(...),
///   ),
/// )
/// ```
class StaggeredItem extends StatefulWidget {
  const StaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 35),
    this.maxDelay = const Duration(milliseconds: 200),
    this.duration,
    this.slideOffset = 0.10,
    this.cap = 6,
  });

  final int index;
  final Widget child;

  /// Delay per index (item 0: 0ms, item 1: 35ms, dst).
  final Duration staggerDelay;

  /// Cap total delay supaya item akhir tidak nunggu kelamaan.
  final Duration maxDelay;

  /// Override entrance duration (default = AppAnimations.medium).
  final Duration? duration;

  /// Vertical slide offset (fraction of widget height) — subtle.
  final double slideOffset;

  /// Hanya `index < cap` yang dianimasikan; sisanya tampil instan TANPA
  /// AnimationController. Mencegah puluhan controller sekaligus di list/grid
  /// panjang (entrance terasa ringan, bukan "wave" berat).
  final int cap;

  @override
  State<StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<StaggeredItem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<Offset>? _slide;

  bool get _animate => widget.index < widget.cap;

  @override
  void initState() {
    super.initState();
    // Di luar cap → tampil instan, TANPA controller (hemat resource).
    if (!_animate) return;
    final c = AnimationController(
      vsync: this,
      duration: widget.duration ?? AppAnimations.medium,
    );
    _controller = c;
    _opacity = CurvedAnimation(parent: c, curve: AppAnimations.smoothSpring);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: c, curve: AppAnimations.smoothSpring));

    // Stagger delay capped supaya tidak nunggu terlalu lama.
    final delayMs = (widget.index * widget.staggerDelay.inMilliseconds).clamp(
      0,
      widget.maxDelay.inMilliseconds,
    );
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Instan kalau di luar cap, controller tak dibuat, atau reduce-motion.
    if (!_animate ||
        _controller == null ||
        AppAnimations.reduceMotion(context)) {
      return widget.child;
    }

    return FadeTransition(
      opacity: _opacity!,
      child: SlideTransition(position: _slide!, child: widget.child),
    );
  }
}
