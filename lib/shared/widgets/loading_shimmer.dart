import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';

/// Helper bungkus widget child dengan shimmer effect.
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceDarkElevated,
      highlightColor: const Color(0xFF2A2A40),
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
              color: AppColors.surfaceDarkElevated,
              borderRadius: BorderRadius.circular(12),
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
            color: AppColors.surfaceDarkElevated,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
