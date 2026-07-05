import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/theme/app_radius.dart';

/// Generic dropdown pill untuk filter Search (Year, Season, Format, Status).
///
/// Tap → buka bottom sheet dengan list opsi single-select. Untuk Genre
/// (multi-select), pakai variant lain — onTap di-handle parent dengan
/// custom modal.
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.onTap,
    this.isActive = false,
  });

  /// Label di atas chip (mis. "Year", "Season").
  final String label;

  /// Nilai yang sedang dipilih, atau "Any" kalau null.
  final String valueLabel;

  /// True kalau ada nilai aktif (selain "Any") — render outline cyan.
  final bool isActive;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted(context),
              letterSpacing: 0.3,
            ),
          ),
        ),
        InkWell(
          onTap: () {
            Haptic.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated(context),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isActive
                    ? AppColors.primaryAdaptive(context)
                    : AppColors.borderColor(context),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? AppColors.primaryAdaptive(context)
                          : AppColors.textMuted(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textMuted(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet picker single-select. Pass list of (value, label) pairs.
/// Return value yang dipilih (atau null kalau user dismiss).
///
/// Pemakaian:
/// ```dart
/// final picked = await showSingleSelectSheet<String>(
///   context: context,
///   title: 'Format',
///   options: [(null, 'Any'), ('TV', 'TV Show'), ('MOVIE', 'Movie')],
///   currentValue: ref.read(selectedFormatProvider),
/// );
/// if (picked != null) ref.read(selectedFormatProvider.notifier).state = picked.$2;
/// ```
Future<T?> showSingleSelectSheet<T>({
  required BuildContext context,
  required String title,
  required List<({T? value, String label})> options,
  required T? currentValue,
}) async {
  return showModalBottomSheet<T?>(
    context: context,
    backgroundColor: AppColors.surfaceElevated(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) {
      return SafeArea(
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
                title,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: options.map((opt) {
                    final isSelected = opt.value == currentValue;
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
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
