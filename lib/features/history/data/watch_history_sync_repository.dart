import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import 'history_entry.dart';

/// Repository sinkron progress nonton ke Supabase (tabel `watch_history`).
///
/// Reuse [HistoryEntry] sebagai model. Semua operasi guard
/// `Env.isSupabaseConfigured && _myId != null` (guest/offline → no-op) dan
/// dibungkus try/catch + debugPrint (pola `xp_repository`). Konflik di-resolve
/// di koordinator (last-write-wins by `watchedAt`).
class WatchHistorySyncRepository {
  static const _table = 'watch_history';

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  bool get isAvailable => Env.isSupabaseConfigured && _myId != null;

  /// Upsert batch entry ke cloud (tambah `user_id`). No-op kalau tak login.
  Future<void> pushEntries(List<HistoryEntry> entries) async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured || entries.isEmpty) return;
    try {
      final rows = entries.map((e) => _toRow(e, id)).toList();
      await Supabase.instance.client
          .from(_table)
          .upsert(rows, onConflict: 'user_id,anime_id,episode_id');
    } catch (e) {
      debugPrint('watch_history pushEntries failed: $e');
    }
  }

  /// Tarik semua row history user dari cloud → [HistoryEntry].
  Future<List<HistoryEntry>> pullAll() async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured) return const [];
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select(
            'anime_id, episode_id, episode_number, '
            'position_seconds, duration_seconds, watched_at',
          )
          .eq('user_id', id);
      return (rows as List).cast<Map<String, dynamic>>().map(_fromRow).toList();
    } catch (e) {
      debugPrint('watch_history pullAll failed: $e');
      return const [];
    }
  }

  Map<String, dynamic> _toRow(HistoryEntry e, String userId) => {
    'user_id': userId,
    'anime_id': e.animeId,
    'episode_id': e.episodeId,
    'episode_number': e.episodeNumber,
    'position_seconds': e.positionSeconds,
    'duration_seconds': e.durationSeconds,
    'watched_at': e.watchedAt.toUtc().toIso8601String(),
  };

  HistoryEntry _fromRow(Map<String, dynamic> row) => HistoryEntry(
    animeId: (row['anime_id'] as num).toInt(),
    episodeId: row['episode_id'] as String,
    episodeNumber: (row['episode_number'] as num?)?.toInt() ?? 1,
    positionSeconds: (row['position_seconds'] as num?)?.toInt() ?? 0,
    durationSeconds: (row['duration_seconds'] as num?)?.toInt(),
    watchedAt:
        DateTime.tryParse(row['watched_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

final watchHistorySyncRepositoryProvider = Provider<WatchHistorySyncRepository>(
  (ref) => WatchHistorySyncRepository(),
);
