import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Opsi kualitas video untuk menu quality (HLS).
class QualityOption {
  const QualityOption({required this.label, this.track});

  /// Label user-facing ("Auto", "1080p", "720p").
  final String label;

  /// Track HLS asli (null = Auto/adaptive). Tipe dynamic supaya overlay
  /// tidak perlu import better_player.
  final BetterPlayerAsmsTrack? track;
}

/// Abstraksi tipis di atas engine playback (BetterPlayer / YouTube) supaya
/// `PlayerControlsOverlay` bisa dipakai seragam.
///
/// Implementasi adalah [ChangeNotifier] — overlay rebuild saat state berubah
/// (posisi/play/buffering). Embed WebView TIDAK pakai ini (kontrol iframe sendiri).
abstract class PlaybackController implements Listenable {
  bool get isInitialized;
  bool get isPlaying;
  bool get isBuffering;
  Duration get position;
  Duration get duration;

  /// Posisi buffer terjauh (untuk track abu-abu di seekbar).
  Duration get buffered;

  double get speed;

  void play();
  void pause();
  void togglePlay();
  void seekTo(Duration position);
  void setSpeed(double speed);

  /// Quality switching hanya didukung HLS (better_player). YouTube auto.
  bool get supportsQuality;
  List<QualityOption> get qualities;
  QualityOption? get currentQuality;
  void setQuality(QualityOption option);

  bool get supportsFullscreen;
  void enterFullscreen();
}

// ─────────────────────────────────────────────────────────────────────────────
// BetterPlayer adapter (HLS / direct mp4)
// ─────────────────────────────────────────────────────────────────────────────

class BetterPlayerPlayback extends ChangeNotifier
    implements PlaybackController {
  BetterPlayerPlayback(this._c) {
    _c.addEventsListener(_onEvent);
  }

  final BetterPlayerController _c;
  QualityOption? _currentQuality;

  /// Kontrol inline disembunyikan (overlay kustom kita yang dipakai).
  static final _inlineControls = const BetterPlayerControlsConfiguration(
    showControls: false,
  );

  /// Saat fullscreen, pakai kontrol bawaan better_player (rotasi + immersive
  /// sudah ditangani engine). Overlay kustom hanya untuk mode inline.
  static final _fullscreenControls = const BetterPlayerControlsConfiguration(
    enableFullscreen: true,
    enableQualities: true,
    enablePlaybackSpeed: true,
    enableSubtitles: true,
    enableSkips: true,
    enablePip: true,
  );

  void _onEvent(BetterPlayerEvent e) {
    // Saat keluar fullscreen → balikkan ke kontrol inline tersembunyi.
    if (e.betterPlayerEventType == BetterPlayerEventType.hideFullscreen) {
      _c.setBetterPlayerControlsConfiguration(_inlineControls);
    }
    // Event apa pun (progress, play, pause, buffering) → refresh overlay.
    notifyListeners();
  }

  VideoPlayerValue? get _v => _c.videoPlayerController?.value;

  @override
  bool get isInitialized => _v?.initialized ?? false;

  @override
  bool get isPlaying => _v?.isPlaying ?? false;

  @override
  bool get isBuffering => _v?.isBuffering ?? false;

  @override
  Duration get position => _v?.position ?? Duration.zero;

  @override
  Duration get duration => _v?.duration ?? Duration.zero;

  @override
  Duration get buffered {
    final ranges = _v?.buffered ?? const [];
    if (ranges.isEmpty) return Duration.zero;
    return ranges.last.end;
  }

  @override
  double get speed => _v?.speed ?? 1.0;

  @override
  void play() => _c.play();

  @override
  void pause() => _c.pause();

  @override
  void togglePlay() => isPlaying ? _c.pause() : _c.play();

  @override
  void seekTo(Duration position) => _c.seekTo(position);

  @override
  void setSpeed(double speed) => _c.setSpeed(speed);

  @override
  bool get supportsQuality => qualities.length > 1;

  @override
  List<QualityOption> get qualities {
    final tracks = _c.betterPlayerAsmsTracks;
    final out = <QualityOption>[const QualityOption(label: 'Auto')];
    // Dedup by height, urut tinggi→rendah.
    final seen = <int>{};
    final sorted = [...tracks]
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    for (final t in sorted) {
      final h = t.height ?? 0;
      if (h == 0 || !seen.add(h)) continue;
      out.add(QualityOption(label: '${h}p', track: t));
    }
    return out;
  }

  @override
  QualityOption? get currentQuality => _currentQuality;

  @override
  void setQuality(QualityOption option) {
    _currentQuality = option;
    final t = option.track;
    if (t != null) {
      _c.setTrack(t);
    } else {
      // Auto → set track kosong (adaptive). better_player pakai track default.
      _c.setTrack(BetterPlayerAsmsTrack.defaultTrack());
    }
    notifyListeners();
  }

  @override
  bool get supportsFullscreen => true;

  @override
  void enterFullscreen() {
    // Aktifkan kontrol bawaan untuk mode fullscreen, lalu masuk fullscreen.
    _c.setBetterPlayerControlsConfiguration(_fullscreenControls);
    _c.enterFullScreen();
  }

  @override
  void dispose() {
    _c.removeEventsListener(_onEvent);
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YouTube adapter (trailer / fallback) — quality auto, fullscreen via toggle
// ─────────────────────────────────────────────────────────────────────────────

class YoutubePlayback extends ChangeNotifier implements PlaybackController {
  YoutubePlayback(this._c) {
    _c.addListener(_onChange);
  }

  final YoutubePlayerController _c;

  void _onChange() => notifyListeners();

  @override
  bool get isInitialized => _c.value.isReady;

  @override
  bool get isPlaying => _c.value.playerState == PlayerState.playing;

  @override
  bool get isBuffering => _c.value.playerState == PlayerState.buffering;

  @override
  Duration get position => _c.value.position;

  @override
  Duration get duration => _c.metadata.duration;

  @override
  Duration get buffered => Duration(
    milliseconds: (_c.value.buffered * duration.inMilliseconds).round(),
  );

  @override
  double get speed => _c.value.playbackRate;

  @override
  void play() => _c.play();

  @override
  void pause() => _c.pause();

  @override
  void togglePlay() => isPlaying ? _c.pause() : _c.play();

  @override
  void seekTo(Duration position) => _c.seekTo(position);

  @override
  void setSpeed(double speed) => _c.setPlaybackRate(speed);

  @override
  bool get supportsQuality => false;

  @override
  List<QualityOption> get qualities => const [];

  @override
  QualityOption? get currentQuality => null;

  @override
  void setQuality(QualityOption option) {}

  @override
  bool get supportsFullscreen => true;

  @override
  void enterFullscreen() => _c.toggleFullScreenMode();

  @override
  void dispose() {
    _c.removeListener(_onChange);
    super.dispose();
  }
}
