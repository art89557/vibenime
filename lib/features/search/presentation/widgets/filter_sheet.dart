import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../../../../core/theme/app_radius.dart';

/// Hasil seleksi dari filter sheet.
///
/// 3 state mungkin:
/// - **`null`** dari `showFilterSheet` → user dismiss (tap di luar / back).
///   Caller harus *tidak mengubah* state.
/// - [FilterChoice.cleared] → user tap "Hapus filter".
///   Caller harus set state ke `null`.
/// - [FilterChoice.value] → user pilih option.
///   Caller harus set state ke value yg dipilih.
class FilterChoice<T> {
  const FilterChoice.value(this.value) : isCleared = false;
  const FilterChoice.cleared() : value = null, isCleared = true;

  final T? value;
  final bool isCleared;
}

/// Modal bottom sheet generic untuk pilih satu opsi dari list.
///
/// Dipakai oleh filter `tahun`, `musim`, `format` di SearchScreen.
///
/// ```dart
/// final result = await showFilterSheet<int>(
///   context: context,
///   title: 'Pilih tahun',
///   options: [for (var y = 2026; y >= 1980; y--)
///     FilterOption(label: '$y', value: y)],
///   currentValue: 2024,
/// );
/// if (result == null) return;          // dismissed
/// if (result.isCleared) {              // tap "Hapus"
///   ref.read(yearProvider.notifier).state = null;
/// } else {
///   ref.read(yearProvider.notifier).state = result.value;
/// }
/// ```
Future<FilterChoice<T>?> showFilterSheet<T>({
  required BuildContext context,
  required String title,
  required List<FilterOption<T>> options,
  T? currentValue,
}) {
  return showModalBottomSheet<FilterChoice<T>?>(
    context: context,
    backgroundColor: AppColors.surfaceElevated(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (ctx) => _FilterSheet<T>(
      title: title,
      options: options,
      currentValue: currentValue,
    ),
  );
}

/// Pasangan label tampil + value yang di-return.
class FilterOption<T> {
  const FilterOption({required this.label, required this.value});
  final String label;
  final T value;
}

class _FilterSheet<T> extends StatelessWidget {
  const _FilterSheet({
    required this.title,
    required this.options,
    this.currentValue,
  });

  final String title;
  final List<FilterOption<T>> options;
  final T? currentValue;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderColor(context),
              borderRadius: BorderRadius.circular(AppRadius.tiny),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                if (currentValue != null)
                  TextButton(
                    onPressed: () {
                      Haptic.light();
                      Navigator.of(
                        context,
                      ).pop<FilterChoice<T>?>(FilterChoice<T>.cleared());
                    },
                    child: Text(
                      'Hapus',
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: AppColors.borderColor(context), height: 1),
          // Options list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: options.length,
              itemBuilder: (context, i) {
                final opt = options[i];
                final isSelected = opt.value == currentValue;
                return InkWell(
                  onTap: () {
                    Haptic.selection();
                    Navigator.of(
                      context,
                    ).pop<FilterChoice<T>?>(FilterChoice<T>.value(opt.value));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt.label,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
