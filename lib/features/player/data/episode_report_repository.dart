import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/observability/error_logger.dart';

/// Repository untuk laporan "episode rusak" → tabel `episode_reports`.
///
/// Best-effort: kalau Supabase belum dikonfigurasi atau user belum login,
/// no-op (return false) tanpa lempar error.
class EpisodeReportRepository {
  Future<bool> report({
    required int anilistId,
    required int episodeNumber,
    String? animeTitle,
    String? sourceId,
    String reason = 'tidak_main',
  }) async {
    if (!Env.isSupabaseConfigured) return false;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false; // harus login untuk lapor

    try {
      await client.from('episode_reports').insert({
        'anilist_id': anilistId,
        'episode_number': episodeNumber,
        'anime_title': animeTitle,
        'source_id': sourceId,
        'reason': reason,
        'reporter_id': userId,
      });
      return true;
    } catch (e, s) {
      ErrorLogger.instance.record(e, s, context: 'EpisodeReport.report');
      debugPrint('episode report failed: $e');
      return false;
    }
  }
}

final episodeReportRepositoryProvider = Provider<EpisodeReportRepository>(
  (ref) => EpisodeReportRepository(),
);
