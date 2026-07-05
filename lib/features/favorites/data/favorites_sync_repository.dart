import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import 'favorite_entry.dart';

/// Repository sinkron favorit/My List ke Supabase (tabel `user_favorites`).
///
/// Mirror pola `WatchHistorySyncRepository`: guard `Env.isSupabaseConfigured
/// && login`, semua try/catch + debugPrint. Konflik & propagasi hapus
/// di-resolve di koordinator ([planMergeFavorites]).
class FavoritesSyncRepository {
  static const _table = 'user_favorites';

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  bool get isAvailable => Env.isSupabaseConfigured && _myId != null;

  /// Upsert batch entry ke cloud. No-op kalau tak login / list kosong.
  Future<void> pushEntries(List<FavoriteEntry> entries) async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured || entries.isEmpty) return;
    try {
      final rows = entries.map((e) => _toRow(e, id)).toList();
      await Supabase.instance.client
          .from(_table)
          .upsert(rows, onConflict: 'user_id,anime_id');
    } catch (e) {
      debugPrint('favorites pushEntries failed: $e');
    }
  }

  /// Hapus batch row cloud by animeId (propagasi hapus lokal).
  Future<void> deleteEntries(List<int> animeIds) async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured || animeIds.isEmpty) return;
    try {
      await Supabase.instance.client
          .from(_table)
          .delete()
          .eq('user_id', id)
          .inFilter('anime_id', animeIds);
    } catch (e) {
      debugPrint('favorites deleteEntries failed: $e');
    }
  }

  /// Tarik semua favorit user dari cloud → [FavoriteEntry].
  Future<List<FavoriteEntry>> pullAll() async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured) return const [];
    try {
      final rows = await Supabase.instance.client
          .from(_table)
          .select(
            'anime_id, title, cover_image, status, total_episodes, '
            'added_at, updated_at',
          )
          .eq('user_id', id);
      return (rows as List).cast<Map<String, dynamic>>().map(_fromRow).toList();
    } catch (e) {
      debugPrint('favorites pullAll failed: $e');
      return const [];
    }
  }

  Map<String, dynamic> _toRow(FavoriteEntry e, String userId) => {
    'user_id': userId,
    'anime_id': e.animeId,
    'title': e.title,
    'cover_image': e.coverImage,
    'status': e.status.code,
    'total_episodes': e.totalEpisodes,
    'added_at': e.addedAt.toUtc().toIso8601String(),
    'updated_at': e.updatedAt.toUtc().toIso8601String(),
  };

  FavoriteEntry _fromRow(Map<String, dynamic> row) {
    final added =
        DateTime.tryParse(row['added_at'] as String? ?? '')?.toLocal() ??
        DateTime.now();
    return FavoriteEntry(
      animeId: (row['anime_id'] as num).toInt(),
      title: (row['title'] as String?) ?? '',
      coverImage: (row['cover_image'] as String?) ?? '',
      status: WatchStatus.fromCode(row['status'] as String?),
      totalEpisodes: (row['total_episodes'] as num?)?.toInt(),
      addedAt: added,
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '')?.toLocal() ??
          added,
    );
  }
}

final favoritesSyncRepositoryProvider = Provider<FavoritesSyncRepository>(
  (ref) => FavoritesSyncRepository(),
);
