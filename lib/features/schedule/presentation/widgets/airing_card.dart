import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/i18n/l10n_extension.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/number_format.dart';
import '../../data/schedule_repository.dart';

// Warna status — hex PERSIS sesuai pattern desain referensi (bukan token
// AppColors.warning #FBBF24, yang berbeda dari spec #FFC107).
const _airedColor = Color(0xFFFFC107); // kuning  — "Sudah Tayang"
const _waitingColor = Color(0xFFFFFFFF); // putih — "Menunggu Update Baru"
const _offColor = Color(0xFFE53935); // merah  — "Telat / Libur / Tamat"

/// Kartu compact untuk satu airing item (1 episode rilis) — tinggi ±70px.
///
/// Bar vertikal 4px di tepi kiri + teks status berwarna senada:
/// - Kuning: episode sudah tayang (airingAt lewat).
/// - Putih : belum tayang (menunggu update baru).
/// - Merah : seri tidak aktif — HIATUS ("Libur") / CANCELLED·FINISHED
///   ("Tamat"). AniList tidak punya sinyal "telat" murni, jadi kategori
///   merah diwakili status seri.
class AiringCard extends StatelessWidget {
  const AiringCard({required this.item, required this.onTap, super.key});

  final AiringItem item;
  final VoidCallback onTap;

  (String, Color) _status(BuildContext context) {
    switch (item.mediaStatus) {
      case 'HIATUS':
        return (context.l10n.scheduleHiatus, _offColor);
      case 'CANCELLED':
      case 'FINISHED':
        return (context.l10n.scheduleFinished, _offColor);
    }
    if (item.airingAt.isAfter(DateTime.now())) {
      return (context.l10n.scheduleWaiting, _waitingColor);
    }
    return (context.l10n.scheduleAired, _airedColor);
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = _status(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        // Border kiri saja tidak bisa digabung borderRadius di Flutter →
        // strip 4px ditaruh DI DALAM ClipRRect supaya ikut lengkung kartu.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md - 1),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bar indikator status — tepi kiri penuh.
                Container(width: 4, color: statusColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                    child: Row(
                      children: [
                        // Jam WIB (compact).
                        SizedBox(
                          width: 44,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.timeWibLabel,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              Text(
                                'WIB',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8,
                                  letterSpacing: 1,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Cover thumb kecil.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: SizedBox(
                            width: 40,
                            height: 54,
                            child: item.coverImage.isEmpty
                                ? Container(color: AppColors.surface(context))
                                : CachedNetworkImage(
                                    imageUrl: item.coverImage,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Judul + meta + status (3 baris padat).
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    'Episode ${item.episode}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10.5,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                  if (item.popularity != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 11,
                                      color: AppColors.textMuted(context),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      compactCount(item.popularity!),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted(context),
                                      ),
                                    ),
                                  ],
                                  if (item.averageScore != null) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: _airedColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      (item.averageScore! / 10).toStringAsFixed(
                                        2,
                                      ),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        color: AppColors.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      statusLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.roboto(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
