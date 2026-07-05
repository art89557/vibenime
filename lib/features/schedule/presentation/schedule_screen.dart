import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../shared/widgets/error_retry.dart';
import 'schedule_providers.dart';
import 'widgets/airing_card.dart';
import 'widgets/day_picker.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  void _shiftDay(WidgetRef ref, DateTime selected, int delta) {
    Haptic.selection();
    ref.read(selectedScheduleDayProvider.notifier).state = selected.add(
      Duration(days: delta),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedScheduleDayProvider);
    final asyncSchedule = ref.watch(airingScheduleProvider);
    final today = DateTime.now();
    final isToday =
        selected.year == today.year &&
        selected.month == today.month &&
        selected.day == today.day;

    final locale = Localizations.localeOf(context).languageCode;
    final prevName = DateFormat(
      'EEEE',
      locale,
    ).format(selected.subtract(const Duration(days: 1)));
    final nextName = DateFormat(
      'EEEE',
      locale,
    ).format(selected.add(const Duration(days: 1)));

    return Scaffold(
      body: SafeArea(
        // Stack: list di belakang + tombol navigasi hari FLOATING di depan
        // (fixed di bawah, tidak ikut scroll).
        child: Stack(
          children: [
            ListView(
              // Bottom padding supaya item terakhir tidak ketutup tombol
              // floating.
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                // Headline
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 6),
                  child: Text(
                    context.l10n.scheduleTitle,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 34,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary(context),
                      height: 1.05,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    '${DateFormat('MMMM', locale).format(selected)} ${selected.year} · ${context.l10n.scheduleTimezone}',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),

                // Day picker — 7 hari fixed, tanpa scroll.
                const DayPicker(),

                const SizedBox(height: 16),

                // Section header "● HARI INI · NAMA-HARI" or just date
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isToday
                            ? '${context.l10n.scheduleToday} · ${DateFormat('EEEE', locale).format(selected).toUpperCase()}'
                            : '${DateFormat('EEEE', locale).format(selected).toUpperCase()} · ${selected.day} ${DateFormat('MMMM', locale).format(selected)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Schedule list
                asyncSchedule.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: ErrorRetry(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(airingScheduleProvider),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.event_busy_outlined,
                                size: 48,
                                color: AppColors.textMuted(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.scheduleEmptyToday,
                                style: GoogleFonts.roboto(
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: items
                          .map(
                            (item) => AiringCard(
                              item: item,
                              onTap: () => context.push(
                                AppRoutes.animeDetailPath(
                                  item.animeId.toString(),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),

            // Tombol navigasi hari — floating, fixed di bawah (safe-area
            // sudah ditangani SafeArea pembungkus Stack).
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DayNavButton(
                    label: prevName,
                    isNext: false,
                    onTap: () => _shiftDay(ref, selected, -1),
                  ),
                  _DayNavButton(
                    label: nextName,
                    isNext: true,
                    onTap: () => _shiftDay(ref, selected, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill floating navigasi hari sebelum/berikutnya — overlay di atas list,
/// diberi shadow supaya tetap terbaca di atas konten.
class _DayNavButton extends StatelessWidget {
  const _DayNavButton({
    required this.label,
    required this.isNext,
    required this.onTap,
  });

  final String label;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: GoogleFonts.roboto(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary(context),
      ),
    );
    final icon = Icon(
      isNext ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
      size: 18,
      color: AppColors.primary,
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh(context),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.borderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: isNext
              ? [text, const SizedBox(width: 6), icon]
              : [icon, const SizedBox(width: 6), text],
        ),
      ),
    );
  }
}
