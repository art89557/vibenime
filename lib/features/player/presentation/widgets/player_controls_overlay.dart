import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptic_helper.dart';
import 'playback_controller.dart';

/// Overlay kontrol video kustom (mirip referensi HiAnime) di atas engine
/// playback apa pun lewat [PlaybackController].
///
/// - Tap area → toggle visibility; auto-hide 3 dtk saat playing.
/// - Tengah: rewind-10 · play/pause · forward-10.
/// - Atas: back, judul + "Episode N", next episode.
/// - Bawah: posisi/durasi + seekbar (buffered) + speed + quality (HLS) + fullscreen.
class PlayerControlsOverlay extends StatefulWidget {
  const PlayerControlsOverlay({
    required this.controller,
    required this.title,
    required this.episodeNumber,
    required this.onBack,
    this.onNextEpisode,
    super.key,
  });

  final PlaybackController controller;
  final String title;
  final int episodeNumber;
  final VoidCallback onBack;
  final VoidCallback? onNextEpisode;

  @override
  State<PlayerControlsOverlay> createState() => _PlayerControlsOverlayState();
}

class _PlayerControlsOverlayState extends State<PlayerControlsOverlay> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _dragging = false;
  double _dragMs = 0;

  /// Posisi X double-tap terakhir (untuk tentukan kiri/kanan/tengah).
  double? _doubleTapX;

  /// Indikator transient "−10"/"+10" saat double-tap seek; null = sembunyi.
  int? _seekFlashSeconds; // negatif = mundur, positif = maju
  Timer? _seekFlashTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekFlashTimer?.cancel();
    super.dispose();
  }

  /// Double-tap: kiri 1/3 = mundur 10s, kanan 1/3 = maju 10s, tengah = play/pause.
  void _onDoubleTap(double width) {
    final c = widget.controller;
    final x = _doubleTapX ?? width / 2;
    if (x < width / 3) {
      Haptic.light();
      c.seekTo(c.position - const Duration(seconds: 10));
      _flashSeek(-10);
    } else if (x > width * 2 / 3) {
      Haptic.light();
      c.seekTo(c.position + const Duration(seconds: 10));
      _flashSeek(10);
    } else {
      Haptic.medium();
      c.togglePlay();
    }
    _poke();
  }

  void _flashSeek(int seconds) {
    setState(() => _seekFlashSeconds = seconds);
    _seekFlashTimer?.cancel();
    _seekFlashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _seekFlashSeconds = null);
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.isPlaying) {
        setState(() => _visible = false);
      }
    });
  }

  void _toggle() {
    setState(() => _visible = !_visible);
    if (_visible) _scheduleHide();
  }

  /// Reset timer tiap kali user berinteraksi.
  void _poke() {
    if (!_visible) setState(() => _visible = true);
    _scheduleHide();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            // Kontrol + tap toggle + double-tap seek.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTapDown: (d) => _doubleTapX = d.localPosition.dx,
              onDoubleTap: () => _onDoubleTap(width),
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_visible,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: AnimatedBuilder(
                      animation: c,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            _topBar(context),
                            _center(c),
                            _bottomBar(context, c),
                            if (c.isBuffering && !_dragging)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2.5,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Flash "−10/+10" — di luar opacity supaya terlihat walau kontrol hidden.
            if (_seekFlashSeconds != null)
              Positioned.fill(child: IgnorePointer(child: _seekFlash())),
          ],
        );
      },
    );
  }

  /// Indikator transient saat double-tap seek (pill di sisi kiri/kanan).
  Widget _seekFlash() {
    final secs = _seekFlashSeconds!;
    final forward = secs > 0;
    return Align(
      alignment: forward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                forward
                    ? Icons.fast_forward_rounded
                    : Icons.fast_rewind_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(height: 2),
              Text(
                '${secs.abs()}s',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _topBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Episode ${widget.episodeNumber}',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onNextEpisode != null)
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                tooltip: 'Episode berikutnya',
                onPressed: () {
                  Haptic.medium();
                  widget.onNextEpisode!();
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── Center transport (rewind / play / forward) ────────────────────────────
  Widget _center(PlaybackController c) {
    return Align(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _circleBtn(
            icon: Icons.replay_10_rounded,
            size: 30,
            onTap: () {
              Haptic.light();
              c.seekTo(c.position - const Duration(seconds: 10));
              _poke();
            },
          ),
          const SizedBox(width: 28),
          _circleBtn(
            icon: c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 46,
            onTap: () {
              Haptic.medium();
              c.togglePlay();
              _poke();
            },
          ),
          const SizedBox(width: 28),
          _circleBtn(
            icon: Icons.forward_10_rounded,
            size: 30,
            onTap: () {
              Haptic.light();
              c.seekTo(c.position + const Duration(seconds: 10));
              _poke();
            },
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required double size,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  // ── Bottom bar (seekbar + actions) ─────────────────────────────────────────
  Widget _bottomBar(BuildContext context, PlaybackController c) {
    final dur = c.duration.inMilliseconds.toDouble();
    final pos = _dragging
        ? _dragMs
        : c.position.inMilliseconds.toDouble().clamp(0, dur <= 0 ? 0 : dur);
    final buffered = c.buffered.inMilliseconds.toDouble().clamp(
      0,
      dur <= 0 ? 0 : dur,
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              Text(
                _fmt(Duration(milliseconds: pos.round())),
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    secondaryActiveTrackColor: Colors.white38,
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    value: pos.toDouble(),
                    max: dur <= 0 ? 1 : dur,
                    secondaryTrackValue: buffered.toDouble(),
                    onChangeStart: (v) {
                      _dragging = true;
                      _dragMs = v;
                      _hideTimer?.cancel();
                    },
                    onChanged: (v) => setState(() => _dragMs = v),
                    onChangeEnd: (v) {
                      c.seekTo(Duration(milliseconds: v.round()));
                      _dragging = false;
                      _scheduleHide();
                    },
                  ),
                ),
              ),
              Text(
                _fmt(c.duration),
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                _textBtn('${_trimSpeed(c.speed)}x', () => _speedSheet(c)),
                if (c.supportsQuality)
                  _textBtn(
                    c.currentQuality?.label ?? 'Auto',
                    () => _qualitySheet(c),
                    icon: Icons.hd_outlined,
                  ),
                const Spacer(),
                if (c.supportsFullscreen)
                  IconButton(
                    icon: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      Haptic.light();
                      c.enterFullscreen();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _trimSpeed(double s) {
    final str = s.toStringAsFixed(2);
    return str.endsWith('0') ? str.substring(0, str.length - 1) : str;
  }

  Widget _textBtn(String label, VoidCallback onTap, {IconData? icon}) {
    return TextButton.icon(
      onPressed: () {
        _poke();
        onTap();
      },
      icon: icon == null
          ? const SizedBox.shrink()
          : Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Future<void> _speedSheet(PlaybackController c) async {
    Haptic.light();
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDarkElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in speeds)
              ListTile(
                dense: true,
                title: Text(
                  '${_trimSpeed(s)}x',
                  style: GoogleFonts.roboto(color: AppColors.textOnDark),
                ),
                trailing: (c.speed - s).abs() < 0.01
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  c.setSpeed(s);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _qualitySheet(PlaybackController c) async {
    Haptic.light();
    final opts = c.qualities;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceDarkElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final q in opts)
              ListTile(
                dense: true,
                title: Text(
                  q.label,
                  style: GoogleFonts.roboto(color: AppColors.textOnDark),
                ),
                trailing: (c.currentQuality?.label ?? 'Auto') == q.label
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () {
                  c.setQuality(q);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }
}
