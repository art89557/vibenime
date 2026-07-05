import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

/// Countdown text widget untuk "Ep N airing in Xd, Yh".
///
/// Pakai `airingAt` (Unix epoch seconds) dari `NextAiringEpisode`.
/// Tick per minute (cukup granular untuk UX, hemat rebuild).
///
/// Auto-stop ticking saat airingAt sudah lewat (return "Aired" / "Just aired").
class AiringCountdown extends StatefulWidget {
  const AiringCountdown({
    super.key,
    required this.episode,
    required this.airingAt,
    this.textStyle,
  });

  /// Nomor episode yang akan tayang.
  final int episode;

  /// Unix epoch seconds — kapan episode tayang.
  final int airingAt;

  final TextStyle? textStyle;

  @override
  State<AiringCountdown> createState() => _AiringCountdownState();
}

class _AiringCountdownState extends State<AiringCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tick per menit — cukup untuk countdown level "days, hours".
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    final airing = DateTime.fromMillisecondsSinceEpoch(widget.airingAt * 1000);
    final now = DateTime.now();
    final diff = airing.difference(now);

    if (diff.isNegative) {
      // Sudah airing
      return 'Ep ${widget.episode} aired';
    }

    final days = diff.inDays;
    final hours = diff.inHours - days * 24;
    final mins = diff.inMinutes - diff.inHours * 60;

    if (days > 0) {
      return 'Ep ${widget.episode} airing in $days d, $hours h';
    }
    if (hours > 0) {
      return 'Ep ${widget.episode} airing in $hours h, $mins m';
    }
    return 'Ep ${widget.episode} airing in $mins m';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatRemaining(),
      style:
          widget.textStyle ??
          GoogleFonts.roboto(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted(context),
          ),
    );
  }
}
