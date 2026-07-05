import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';

/// Satu item airing — anime + episode + airingAt timestamp.
class AiringItem {
  const AiringItem({
    required this.animeId,
    required this.title,
    required this.coverImage,
    required this.episode,
    required this.airingAt,
    this.format,
    this.averageScore,
    this.popularity,
    this.mediaStatus,
  });

  final int animeId;
  final String title;
  final String coverImage;
  final int episode;

  /// Local DateTime di zona WIB (UTC+7).
  final DateTime airingAt;

  final String? format;
  final int? averageScore;

  /// Jumlah user AniList yang punya anime ini di list — dipakai sebagai
  /// metrik "views" di kartu jadwal (AniList tak punya view count asli).
  final int? popularity;

  /// Status seri dari AniList (`RELEASING`/`FINISHED`/`NOT_YET_RELEASED`/
  /// `CANCELLED`/`HIATUS`). Dipakai kartu jadwal untuk kategori MERAH:
  /// HIATUS → "Libur", CANCELLED/FINISHED → "Tamat". AniList tidak punya
  /// sinyal "telat", jadi kategori itu diwakili status seri tidak aktif.
  final String? mediaStatus;

  /// True kalau airing time dalam ±1 jam dari sekarang.
  bool get isLive {
    final now = DateTime.now();
    final diff = airingAt.difference(now).inMinutes;
    return diff.abs() < 60;
  }

  /// Time WIB format "HH:MM".
  String get timeWibLabel {
    final wib = airingAt.toUtc().add(const Duration(hours: 7));
    final h = wib.hour.toString().padLeft(2, '0');
    final m = wib.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Countdown string (mis. "4j 28m") atau null kalau sudah lewat / live.
  String? get countdownLabel {
    if (isLive) return null;
    final now = DateTime.now();
    final diff = airingAt.difference(now);
    if (diff.isNegative) return null;
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) return '${hours}j ${minutes}m';
    return '${minutes}m';
  }
}

class ScheduleRepository {
  ScheduleRepository(this._client);

  final AniListClient _client;

  /// Ambil airing schedule untuk hari tertentu (WIB).
  Future<List<AiringItem>> fetchForDay(DateTime day) async {
    // Gunakan UTC range yang cover full day di WIB.
    // WIB = UTC+7. Day 00:00 WIB = previous day 17:00 UTC.
    final startWib = DateTime(day.year, day.month, day.day);
    final endWib = startWib.add(const Duration(days: 1));
    final startUtc = startWib.toUtc().subtract(const Duration(hours: 7));
    final endUtc = endWib.toUtc().subtract(const Duration(hours: 7));

    final data = await _client.query(
      AniListQueries.airingSchedule,
      variables: {
        'airingAt_greater': startUtc.millisecondsSinceEpoch ~/ 1000,
        'airingAt_lesser': endUtc.millisecondsSinceEpoch ~/ 1000,
      },
    );

    final schedules =
        ((data['Page'] as Map<String, dynamic>?)?['airingSchedules']
            as List?) ??
        const [];

    return schedules
        .cast<Map<String, dynamic>>()
        .where((s) {
          final media = s['media'] as Map<String, dynamic>?;
          return media != null && media['isAdult'] != true;
        })
        .map((s) {
          final media = s['media'] as Map<String, dynamic>;
          final title = media['title'] as Map<String, dynamic>? ?? const {};
          final cover =
              media['coverImage'] as Map<String, dynamic>? ?? const {};
          return AiringItem(
            animeId: (media['id'] as num).toInt(),
            title: (title['english'] ?? title['romaji'] ?? '?') as String,
            coverImage: (cover['medium'] ?? cover['large'] ?? '') as String,
            episode: (s['episode'] as num).toInt(),
            airingAt: DateTime.fromMillisecondsSinceEpoch(
              (s['airingAt'] as num).toInt() * 1000,
              isUtc: true,
            ).toLocal(),
            format: media['format'] as String?,
            averageScore: (media['averageScore'] as num?)?.toInt(),
            popularity: (media['popularity'] as num?)?.toInt(),
            mediaStatus: media['status'] as String?,
          );
        })
        .toList();
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(anilistClientProvider)),
);
