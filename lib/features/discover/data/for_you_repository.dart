import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../../shared/models/anime.dart';
import '../../favorites/data/favorite_entry.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../favorites/presentation/favorites_providers.dart';
import '../../history/data/history_entry.dart';
import '../../history/data/history_repository.dart';
import '../../history/presentation/history_providers.dart';

/// Hasil rekomendasi "Untuk Kamu" — daftar anime + genre dasar (untuk subtitle).
class ForYouResult {
  const ForYouResult({required this.items, required this.basedOnGenres});

  final List<Anime> items;
  final List<String> basedOnGenres;

  bool get isEmpty => items.isEmpty;

  static const empty = ForYouResult(items: [], basedOnGenres: []);
}

/// Rekomendasi personal berdasarkan **afinitas genre** dari anime yang user
/// favorit + tonton. Murni client-side (tanpa server ML):
/// 1. Kumpulkan seed (favorit berbobot 2-3, history 1).
/// 2. Ambil genre tiap seed → skor genre tertimbang.
/// 3. Browse anime populer di top-genre, exclude yang sudah ditonton/favorit.
class ForYouRepository {
  ForYouRepository(this._client, this._favorites, this._history);

  final AniListClient _client;
  final FavoritesRepository _favorites;
  final HistoryRepository _history;

  Future<ForYouResult> recommend({int limit = 15}) async {
    // 1. Seed berbobot: animeId → weight.
    final weights = weightSeeds(
      favorites: _favorites.getAll(),
      history: _history.recentWatched(limit: 30),
    );
    if (weights.isEmpty) return ForYouResult.empty;

    final seedIds = weights.keys.toList();

    // 2. Genre tiap seed → skor tertimbang → top genre.
    Map<String, dynamic> genreData;
    try {
      genreData = await _client.query(
        AniListQueries.mediaGenresByIds,
        variables: {'ids': seedIds.take(50).toList()},
      );
    } catch (e) {
      debugPrint('forYou genres fetch failed: $e');
      return ForYouResult.empty;
    }
    final seedMedia =
        ((genreData['Page'] as Map<String, dynamic>?)?['media'] as List?) ??
        const [];
    final seedGenres = <int, List<String>>{};
    for (final m in seedMedia.cast<Map<String, dynamic>>()) {
      final id = (m['id'] as num).toInt();
      seedGenres[id] = ((m['genres'] as List?) ?? const []).cast<String>();
    }
    final topGenres = rankGenres(seedGenres, weights, take: 3);
    if (topGenres.isEmpty) return ForYouResult.empty;

    // 3. Browse populer di top-genre, exclude seed.
    Map<String, dynamic> browseData;
    try {
      browseData = await _client.query(
        AniListQueries.mediaBrowse,
        variables: {
          'genre_in': topGenres,
          'sort': ['POPULARITY_DESC', 'SCORE_DESC'],
          'perPage': 40,
        },
        fetchPolicy: FetchPolicy.noCache,
      );
    } catch (e) {
      debugPrint('forYou browse failed: $e');
      return ForYouResult.empty;
    }
    final browseMedia =
        ((browseData['Page'] as Map<String, dynamic>?)?['media'] as List?) ??
        const [];

    final seen = seedIds.toSet();
    final out = <Anime>[];
    for (final m in browseMedia.cast<Map<String, dynamic>>()) {
      final anime = Anime.fromAniListMedia(m);
      if (!seen.add(anime.id)) continue; // skip seed / duplikat
      out.add(anime);
      if (out.length >= limit) break;
    }

    return ForYouResult(items: out, basedOnGenres: topGenres);
  }
}

/// Hitung bobot seed per anime (pure → mudah di-test). Favorit menyumbang
/// lebih besar dari history karena sinyal eksplisit:
/// - favorit `watching`/`completed` = 3, `planning` = 2
/// - tiap anime di history = +1
/// Bobot diakumulasi kalau anime muncul di dua sumber.
Map<int, int> weightSeeds({
  required List<FavoriteEntry> favorites,
  required List<HistoryEntry> history,
}) {
  final weights = <int, int>{};
  for (final f in favorites) {
    final w = switch (f.status) {
      WatchStatus.completed => 3,
      WatchStatus.watching => 3,
      WatchStatus.planning => 2,
    };
    weights[f.animeId] = (weights[f.animeId] ?? 0) + w;
  }
  for (final h in history) {
    weights[h.animeId] = (weights[h.animeId] ?? 0) + 1;
  }
  return weights;
}

/// Ranking genre dari skor tertimbang (pure → mudah di-test). Tiap genre dapat
/// skor = jumlah bobot anime-seed yang punya genre itu. Return top-[take] genre
/// urut skor menurun.
List<String> rankGenres(
  Map<int, List<String>> seedGenres,
  Map<int, int> weights, {
  int take = 3,
}) {
  final score = <String, int>{};
  seedGenres.forEach((id, genres) {
    final w = weights[id] ?? 1;
    for (final g in genres) {
      score[g] = (score[g] ?? 0) + w;
    }
  });
  final sorted = score.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(take).map((e) => e.key).toList();
}

final forYouRepositoryProvider = Provider<ForYouRepository>((ref) {
  return ForYouRepository(
    ref.watch(anilistClientProvider),
    ref.watch(favoritesRepositoryProvider),
    ref.watch(historyRepositoryProvider),
  );
});

/// Rekomendasi "Untuk Kamu" — auto-recompute saat favorit / history berubah.
final forYouProvider = FutureProvider.autoDispose<ForYouResult>((ref) async {
  ref.watch(favoritesProvider); // rebuild saat favorit berubah
  ref.watch(historyChangesProvider); // rebuild saat history berubah
  return ref.watch(forYouRepositoryProvider).recommend();
});
