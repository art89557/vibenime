import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

/// Helper bungkus widget child dengan shimmer effect — adaptive theme.
///
/// Auto-switch shimmer base/highlight color berdasarkan brightness:
/// - Dark: surfaceDarkElevated → surfaceDarkHigh
/// - Light: light grey → lighter grey
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? AppColors.surfaceElevated(context)
          : const Color(0xFFE5E7EB),
      highlightColor: isDark
          ? const Color(0xFF2A2A40)
          : const Color(0xFFF5F5F5),
      child: child,
    );
  }
}

/// Skeleton untuk satu baris horizontal AnimeCard di Home.
class AnimeRowSkeleton extends StatelessWidget {
  const AnimeRowSkeleton({this.itemCount = 5, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 270,
      child: LoadingShimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Container(
            width: 130,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton untuk grid Search / My List.
class AnimeGridSkeleton extends StatelessWidget {
  const AnimeGridSkeleton({this.itemCount = 9, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: GridView.builder(
        // shrinkWrap + non-scrollable: aman saat di-nest di dalam scroll view
        // lain (cegah "Vertical viewport unbounded height").
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.48,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) => Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

/// Skeleton untuk daftar Card Library (horizontal carousel) — judul + EP.
class LibraryCardSkeleton extends StatelessWidget {
  const LibraryCardSkeleton({this.itemCount = 3, super.key});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: LoadingShimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, _) => Container(
            width: 240,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}
