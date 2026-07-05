import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/animation/animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../schedule_providers.dart';

/// Header hari SEN–MIN dalam **1 baris fixed** (7 × Expanded — selalu muat
/// pas lebar layar, TANPA horizontal scroll, aman sampai layar 320px).
///
/// Sel compact: nama hari 3-huruf di atas, angka tanggal di bawah.
/// Hari aktif = background cyan kontras tinggi dengan teks gelap;
/// "hari ini" yang tidak aktif diberi ring border primary.
class DayPicker extends ConsumerWidget {
  const DayPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedScheduleDayProvider);
    final today = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode;

    // Senin di minggu yang sedang dipilih (week view Senin-based).
    final monday = selected.subtract(Duration(days: selected.weekday - 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _DayCell(
                  label: DateFormat(
                    'EEE',
                    locale,
                  ).format(monday.add(Duration(days: i))).toUpperCase(),
                  day: monday.add(Duration(days: i)),
                  selected: selected,
                  today: today,
                  onTap: () {
                    Haptic.selection();
                    ref.read(selectedScheduleDayProvider.notifier).state =
                        monday.add(Duration(days: i));
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.label,
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  final String label;
  final DateTime day;
  final DateTime selected;
  final DateTime today;
  final VoidCallback onTap;

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final isActive = _sameDate(day, selected);
    final isToday = _sameDate(day, today);
    final reduce = AppAnimations.reduceMotion(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 56,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : (isToday
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.borderColor(context)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.surface(context)
                    : AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: GoogleFonts.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1,
                color: isActive
                    ? AppColors.surface(context)
                    : AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
