import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav_helper.dart';
import 'player_providers.dart';
import 'player_screen.dart';

/// Guard yang detect platform: kalau mobile (Android/iOS) → render
/// [PlayerScreen] dengan better_player & youtube_player. Kalau web/desktop
/// (tidak support 2 lib itu), render fallback screen yang launch video URL
/// di browser external.
///
/// Sementara waiting Phase I-full (media_kit integration), ini bikin app
/// tidak crash di web/desktop dan kasih UX "open in browser" sebagai
/// stop-gap.
class PlayerPlatformGuard extends ConsumerWidget {
  const PlayerPlatformGuard({
    super.key,
    required this.animeId,
    required this.episodeId,
  });

  final String animeId;
  final String episodeId;

  /// True kalau platform punya support better_player_plus + youtube_player_flutter.
  static bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isMobile) {
      return PlayerScreen(animeId: animeId, episodeId: episodeId);
    }
    return _DesktopWebFallback(animeId: animeId, episodeId: episodeId);
  }
}

class _DesktopWebFallback extends ConsumerWidget {
  const _DesktopWebFallback({required this.animeId, required this.episodeId});

  final String animeId;
  final String episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animeIdInt = int.tryParse(animeId) ?? 0;
    final payloadsAsync = ref.watch(
      streamPayloadsProvider((animeId: animeIdInt, episodeId: episodeId)),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
        title: const Text('Pemutar'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 52,
                    color: AppColors.primaryAdaptive(context),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Pemutar Belum Tersedia',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pemutar embedded saat ini hanya tersedia di aplikasi mobile. '
                  'Di web/desktop, kamu bisa buka video di browser eksternal '
                  'atau pakai aplikasi VibeNime di HP.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: AppColors.textMuted(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                payloadsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text(
                    'Gagal load sumber: $e',
                    style: TextStyle(color: AppColors.error),
                  ),
                  data: (payloads) {
                    if (payloads.isEmpty) {
                      return Text(
                        'Sumber video tidak ditemukan.',
                        style: GoogleFonts.roboto(
                          color: AppColors.textMuted(context),
                        ),
                      );
                    }
                    final first = payloads.first;
                    // YouTube trailer atau primary source (HLS/mp4)
                    final urlString = first.isYoutube
                        ? 'https://www.youtube.com/watch?v=${first.youtubeVideoId}'
                        : first.primarySource?.url;
                    return Column(
                      children: [
                        FilledButton.icon(
                          onPressed: urlString == null
                              ? null
                              : () async {
                                  final uri = Uri.tryParse(urlString);
                                  if (uri != null) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Buka di Browser'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              context.go(AppRoutes.animeDetailPath(animeId)),
                          child: const Text('Kembali ke Detail Anime'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
