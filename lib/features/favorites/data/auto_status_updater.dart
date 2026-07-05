import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/data/history_repository.dart';
import '../../social/data/activity_repository.dart';
import 'favorite_entry.dart';
import 'favorites_repository.dart';

/// Service yang sync `WatchStatus` di FavoriteEntry berdasarkan history.
///
/// **Aturan promote** (one-way only, sticky):
/// - `planning` + history.allForAnime non-empty → `watching`
/// - `watching` + last episode `isFinished` → `completed`
///
/// Tidak demote: completed tetap completed walau user delete history.
/// User bisa override manual via status picker di Detail.
class AutoStatusUpdater {
  AutoStatusUpdater(this._fav, this._history, this._activity);

  final FavoritesRepository _fav;
  final HistoryRepository _history;
  final ActivityRepository _activity;

  /// Dipanggil setelah `HistoryEntry.save()` ke Hive. Idempotent — kalau
  /// status sudah sesuai, no-op (FavoritesRepository.setStatus juga skip
  /// redundant writes).
  ///
  /// [totalEpisodes] optional — kalau tahu count fresh dari Anime model,
  /// kasih. Kalau null, fallback ke `entry.totalEpisodes` (snapshot saat
  /// add ke list). Kalau dua-duanya null → tidak bisa detect "last ep" →
  /// hanya promote ke watching maksimal.
  Future<void> onHistorySaved(int animeId, {int? totalEpisodes}) async {
    final entry = _fav.getEntry(animeId);
    if (entry == null) return; // anime belum di-list — skip
    if (entry.status == WatchStatus.completed) return; // sticky

    final allHistory = _history.allForAnime(animeId);
    if (allHistory.isEmpty) return;

    final total = totalEpisodes ?? entry.totalEpisodes;
    final reachedFinal =
        total != null &&
        allHistory.any((h) => h.isFinished && h.episodeNumber >= total);

    if (reachedFinal) {
      await _fav.setStatus(animeId, WatchStatus.completed);
      debugPrint('AutoStatus: anime $animeId → COMPLETED');
      // Log activity untuk feed friends
      await _activity.logEvent(
        type: ActivityEventType.completedAnime,
        animeId: animeId,
        animeTitle: entry.title,
        animeCover: entry.coverImage,
      );
    } else if (entry.status == WatchStatus.planning) {
      await _fav.setStatus(animeId, WatchStatus.watching);
      debugPrint('AutoStatus: anime $animeId → WATCHING');
    }
    // Log watched_episode event (best-effort, capped) — kalau ada history
    // entry terbaru, log episode-nya.
    final latest = _history.latestForAnime(animeId);
    if (latest != null) {
      await _activity.logEvent(
        type: ActivityEventType.watchedEpisode,
        animeId: animeId,
        animeTitle: entry.title,
        animeCover: entry.coverImage,
        metadata: {'episode': latest.episodeNumber},
      );
    }
  }
}

final autoStatusUpdaterProvider = Provider<AutoStatusUpdater>((ref) {
  return AutoStatusUpdater(
    ref.watch(favoritesRepositoryProvider),
    ref.watch(historyRepositoryProvider),
    ref.watch(activityRepositoryProvider),
  );
});
