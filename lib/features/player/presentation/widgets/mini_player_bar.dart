import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/utils/haptic_helper.dart';
import '../player_session.dart';

/// Mini player (PiP) — bar tipis ~64dp docked di atas bottom nav. Muncul hanya
/// saat [PlayerSession.phase] == minimized. Video tetap main (controller sama
/// dimiliki [PlayerSessionNotifier]). Tap bar → expand balik ke full player.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  static const double height = 64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playerSessionProvider);
    if (session.phase != PlayerPhase.minimized) {
      return const SizedBox.shrink();
    }
    final notifier = ref.read(playerSessionProvider.notifier);
    final controller = notifier.controller;
    final playback = notifier.playback;

    void expand() {
      Haptic.light();
      notifier.expand();
      context.push(
        AppRoutes.playerPath(session.animeId.toString(), session.episodeId),
      );
    }

    return Material(
      color: AppColors.surfaceHigh(context),
      child: InkWell(
        onTap: expand,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.borderColor(context)),
            ),
          ),
          child: Row(
            children: [
              // ── Preview video live ──
              // Saat minimized, route player sudah lepas; mount video di sini.
              // Aman karena controller dibuat dengan autoDispose:false → unmount
              // BetterPlayer tidak men-dispose controller (lihat PlayerSession).
              _Preview(
                controller: controller,
                coverImage: session.coverImage,
                mountVideo: controller != null,
              ),
              const SizedBox(width: 10),
              // ── Judul + episode ──
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title.isEmpty ? 'VibeNime' : session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Episode ${session.episodeNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Play/Pause ──
              if (playback != null)
                AnimatedBuilder(
                  animation: playback,
                  builder: (_, _) => IconButton(
                    iconSize: 26,
                    color: AppColors.textPrimary(context),
                    icon: Icon(
                      playback.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: () {
                      Haptic.light();
                      playback.togglePlay();
                    },
                  ),
                ),
              // ── Close ──
              IconButton(
                iconSize: 22,
                color: AppColors.textMuted(context),
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  Haptic.light();
                  notifier.close();
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview kiri mini bar — video live (kalau boleh di-mount) atau cover.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.controller,
    required this.coverImage,
    required this.mountVideo,
  });

  final BetterPlayerController? controller;
  final String coverImage;
  final bool mountVideo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(0),
        bottomLeft: Radius.circular(0),
        topRight: Radius.circular(AppRadius.sm),
        bottomRight: Radius.circular(AppRadius.sm),
      ),
      child: SizedBox(
        width: 112,
        height: MiniPlayerBar.height,
        child: ColoredBox(
          color: Colors.black,
          child: mountVideo && controller != null
              ? BetterPlayer(controller: controller!)
              : (coverImage.isEmpty
                    ? const SizedBox.shrink()
                    : CachedNetworkImage(
                        imageUrl: coverImage,
                        fit: BoxFit.cover,
                      )),
        ),
      ),
    );
  }
}
