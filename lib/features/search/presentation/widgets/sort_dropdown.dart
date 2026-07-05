import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../search_providers.dart';
import '../../../../core/theme/app_radius.dart';

/// Mini dropdown trailing untuk sort options. Style: text + arrow icon
/// kecil, tidak ada border. Match AniList-style sort selector di kanan
/// atas grid result.
class SortDropdown extends ConsumerWidget {
  const SortDropdown({super.key});

  /// Mapping AniList enum → UI label.
  static const List<({String value, String label})> _options = [
    (value: 'POPULARITY_DESC', label: 'Popularity'),
    (value: 'SCORE_DESC', label: 'Average Score'),
    (value: 'TRENDING_DESC', label: 'Trending'),
    (value: 'FAVOURITES_DESC', label: 'Favorites'),
    (value: 'UPDATED_AT_DESC', label: 'Date Added'),
    (value: 'START_DATE_DESC', label: 'Release Date'),
    (value: 'TITLE_ROMAJI', label: 'Title'),
  ];

  static String labelFor(String value) {
    return _options
        .firstWhere(
          (o) => o.value == value,
          orElse: () => (value: value, label: value),
        )
        .label;
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final current = ref.read(sortProvider);
    Haptic.selection();
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceElevated(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.tiny),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Urutkan',
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              ..._options.map((opt) {
                final isSelected = opt.value == current;
                return InkWell(
                  onTap: () {
                    Haptic.selection();
                    Navigator.pop(ctx, opt.value);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryAdaptive(
                              context,
                            ).withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt.label,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primaryAdaptive(context)
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: AppColors.primaryAdaptive(context),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
    if (picked != null && picked != current) {
      ref.read(sortProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sortProvider);
    return InkWell(
      onTap: () => _pick(context, ref),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: AppColors.textMuted(context),
            ),
            const SizedBox(width: 4),
            Text(
              labelFor(current),
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
