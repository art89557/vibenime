import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/playback_controller.dart';

/// Fase mini player global.
enum PlayerPhase {
  /// Tidak ada sesi aktif.
  closed,

  /// Player tampil penuh (route `/player`).
  full,

  /// Player mengecil jadi bar di atas bottom nav, video tetap main (PiP).
  minimized,
}

/// State sesi player global (immutable). Metadata untuk mini bar + fase.
class PlayerSession {
  const PlayerSession({
    required this.phase,
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.title,
    required this.coverImage,
    required this.isNative,
    required this.videoInRoute,
  });

  const PlayerSession.closed()
    : phase = PlayerPhase.closed,
      animeId = 0,
      episodeId = '',
      episodeNumber = 0,
      title = '',
      coverImage = '',
      isNative = false,
      videoInRoute = false;

  final PlayerPhase phase;
  final int animeId;
  final String episodeId;
  final int episodeNumber;
  final String title;
  final String coverImage;

  /// True kalau source aktif = video native better_player (HLS/mp4) — hanya
  /// source ini yang boleh di-mini. YouTube/WebView embed → false.
  final bool isNative;

  /// True saat route `/player` sedang me-mount BetterPlayer. Mini bar HANYA
  /// boleh me-mount BetterPlayer saat `minimized && !videoInRoute` supaya tidak
  /// pernah ada dua BetterPlayer widget ke controller yang sama (dual-surface).
  final bool videoInRoute;

  bool isSame(int animeId, String episodeId) =>
      this.animeId == animeId && this.episodeId == episodeId;

  PlayerSession copyWith({
    PlayerPhase? phase,
    int? animeId,
    String? episodeId,
    int? episodeNumber,
    String? title,
    String? coverImage,
    bool? isNative,
    bool? videoInRoute,
  }) {
    return PlayerSession(
      phase: phase ?? this.phase,
      animeId: animeId ?? this.animeId,
      episodeId: episodeId ?? this.episodeId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      coverImage: coverImage ?? this.coverImage,
      isNative: isNative ?? this.isNative,
      videoInRoute: videoInRoute ?? this.videoInRoute,
    );
  }
}

/// Pemilik **tunggal** `BetterPlayerController` + `BetterPlayerPlayback` selama
/// satu sesi tontonan. Controller dibuat oleh route player lalu di-`register`
/// ke sini; saat user tekan back, route `minimize()` (controller TIDAK
/// di-dispose) → video lanjut main di mini bar. Dispose hanya saat `close()`
/// atau ganti episode.
///
/// Lihat [PlayerSession.videoInRoute] untuk mekanisme anti dual-surface.
class PlayerSessionNotifier extends Notifier<PlayerSession> {
  BetterPlayerController? controller;
  BetterPlayerPlayback? playback;

  @override
  PlayerSession build() => const PlayerSession.closed();

  bool get hasController => controller != null;

  /// Apakah controller aktif untuk episode (anime+episode) tertentu — dipakai
  /// route untuk memutuskan adopt (re-expand) vs buat baru (ganti episode).
  bool hasControllerFor(int animeId, String episodeId) =>
      controller != null && state.isSame(animeId, episodeId);

  /// Daftarkan controller native yang baru dibuat route. Set fase full.
  void register({
    required BetterPlayerController controller,
    required BetterPlayerPlayback playback,
    required int animeId,
    required String episodeId,
    required int episodeNumber,
    required String title,
    required String coverImage,
  }) {
    this.controller = controller;
    this.playback = playback;
    state = PlayerSession(
      phase: PlayerPhase.full,
      animeId: animeId,
      episodeId: episodeId,
      episodeNumber: episodeNumber,
      title: title,
      coverImage: coverImage,
      isNative: true,
      videoInRoute: true,
    );
  }

  /// Route mengadopsi controller yang masih hidup (saat re-expand dari mini).
  void markFull() =>
      state = state.copyWith(phase: PlayerPhase.full, videoInRoute: true);

  /// Source non-native (YouTube/WebView) — tak bisa di-mini. Tandai supaya
  /// PopScope route menutup normal.
  void markNonNative() {
    state = state.copyWith(phase: PlayerPhase.full, isNative: false);
  }

  /// Update metadata judul/cover/nomor episode saat sudah diketahui route.
  void updateMeta({String? title, String? coverImage, int? episodeNumber}) {
    if (state.phase == PlayerPhase.closed) return;
    state = state.copyWith(
      title: title,
      coverImage: coverImage,
      episodeNumber: episodeNumber,
    );
  }

  /// Apakah route sedang memegang surface video.
  void setVideoInRoute(bool value) {
    if (state.phase == PlayerPhase.closed) return;
    state = state.copyWith(videoInRoute: value);
  }

  /// Kecilkan ke mini bar (video tetap main). No-op kalau tak ada controller.
  void minimize() {
    if (controller == null || !state.isNative) return;
    state = state.copyWith(phase: PlayerPhase.minimized);
  }

  /// Besarkan kembali ke full (dipanggil sebelum push `/player`).
  void expand() {
    if (state.phase == PlayerPhase.minimized) {
      state = state.copyWith(phase: PlayerPhase.full);
    }
  }

  /// Tutup sesi total — dispose controller + reset.
  void close() {
    playback?.dispose();
    // forceDispose: controller dibuat dengan autoDispose:false supaya tahan
    // unmount BetterPlayer widget → di sini baru benar-benar di-dispose.
    controller?.dispose(forceDispose: true);
    playback = null;
    controller = null;
    state = const PlayerSession.closed();
  }
}

final playerSessionProvider =
    NotifierProvider<PlayerSessionNotifier, PlayerSession>(
      PlayerSessionNotifier.new,
    );
