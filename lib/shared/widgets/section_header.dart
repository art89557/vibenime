import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/i18n/l10n_extension.dart';
import '../../core/theme/app_colors.dart';

/// Section header v2 — serif italic + opsional refresh action di kanan.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.onRefresh,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text(context.l10n.seeAll)),
          if (onRefresh != null)
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('refresh', style: GoogleFonts.roboto(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
  }
}

/// Mono uppercase label kecil — dipakai untuk "BUAT KAMI TAHU",
/// "TRENDING DI INDONESIA", dll.
class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textMuted(context),
      ),
    );
  }
}
