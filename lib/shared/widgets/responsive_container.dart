import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';

/// Constrain child ke `Breakpoints.maxContentWidth(context)` — center kalau
/// layar lebih lebar dari max width. Mencegah text/grid stretching weird di
/// monitor besar.
///
/// Pakai di body Scaffold yang scrollable, sebelum padding apapun.
/// Mobile: max = infinity → no-op transparent.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final maxW = Breakpoints.maxContentWidth(context);
    if (!maxW.isFinite) return child;
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }
}

/// Builder yang menyediakan jumlah kolom adaptive untuk grid.
///
/// Usage:
/// ```dart
/// AdaptiveGrid(
///   itemBuilder: (ctx, i) => AnimeCard(...),
///   itemCount: 24,
/// )
/// ```
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.padding = const EdgeInsets.all(16),
    this.mainAxisSpacing = 16,
    this.crossAxisSpacing = 12,
    this.childAspectRatio = 0.52,
    this.controller,
  });

  final Widget? Function(BuildContext, int) itemBuilder;
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Breakpoints.columnsFor(context),
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
