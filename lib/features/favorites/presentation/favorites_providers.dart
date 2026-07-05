import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/data/history_repository.dart';
import '../../history/presentation/history_providers.dart';
import '../data/favorite_entry.dart';
import '../data/favorites_repository.dart';

/// Stream daftar semua entry — auto rebuild widget saat add/remove/setStatus.
final favoritesProvider = StreamProvider<List<FavoriteEntry>>((ref) {
  return ref.watch(favoritesRepositoryProvider).watchAll();
});

/// Entry untuk satu anime — null kalau belum di-list. Watch ke
/// `favoritesProvider` supaya update saat box berubah.
final favoriteEntryProvider = Provider.family<FavoriteEntry?, int>((
  ref,
  animeId,
) {
  final all = ref.watch(favoritesProvider).valueOrNull ?? const [];
  for (final e in all) {
    if (e.animeId == animeId) return e;
  }
  return null;
});

/// True kalau anime ada di list (status apapun). Boolean wrapper untuk
/// backward compat dengan UI yang cuma butuh tahu "is in list".
final isFavoriteProvider = Provider.family<bool, int>((ref, animeId) {
  return ref.watch(favoriteEntryProvider(animeId)) != null;
});

/// Filter entry by status. `null` = semua.
///
/// Pakai di Library tabs:
/// ```dart
/// ref.watch(favoritesByStatusProvider(WatchStatus.watching))
/// ```
final favoritesByStatusProvider =
    Provider.family<List<FavoriteEntry>, WatchStatus?>((ref, status) {
      final all = ref.watch(favoritesProvider).valueOrNull ?? const [];
      if (status == null) return all;
      return all.where((e) => e.status == status).toList();
    });

/// Progress tonton untuk anime tertentu. Computed dari history Hive.
///
/// - [current]: episode tertinggi yang pernah di-watch (`positionSeconds >= 30`
///   atau `isFinished`).
/// - [total]: total episode dari entry.totalEpisodes (snapshot saat add).
/// - [fraction]: 0.0 - 1.0 untuk progress bar (return 0 kalau total null).
typedef AnimeProgress = ({int current, int? total, double fraction});

final progressProvider = Provider.family<AnimeProgress, int>((ref, animeId) {
  ref.watch(historyChangesProvider); // re-eval saat history berubah
  final history = ref.watch(historyRepositoryProvider);
  final entry = ref.watch(favoriteEntryProvider(animeId));

  final epEntries = history.allForAnime(animeId);
  // Episode tertinggi yang dianggap "watched" (>=30s atau finished).
  int current = 0;
  for (final h in epEntries) {
    if (h.isFinished || h.positionSeconds >= 30) {
      if (h.episodeNumber > current) current = h.episodeNumber;
    }
  }
  final total = entry?.totalEpisodes;
  final fraction = (total == null || total == 0)
      ? 0.0
      : (current / total).clamp(0.0, 1.0);
  return (current: current, total: total, fraction: fraction);
});
