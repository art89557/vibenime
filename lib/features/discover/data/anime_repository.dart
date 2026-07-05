import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../../shared/models/anime.dart';

enum DiscoverSection { trending, popular, topRated, upcoming, completed }

class AnimeRepository {
  AnimeRepository(this._client);

  final AniListClient _client;
  static final _random = Random();

  Future<List<Anime>> fetchSection(
    DiscoverSection section, {
    int page = 1,
    int perPage = 20,
  }) async {
    // **Randomize "popular" page (1-5)** — refresh button user-tap mau kasih
    // result yang berbeda. AniList page 1 = top-12 popular, page 2-5 = next
    // tier. Cara paling ringan untuk "shuffle" feeling tanpa client-side hack.
    final effectivePage = section == DiscoverSection.popular
        ? _random.nextInt(5) + 1
        : page;
    final variables = <String, dynamic>{
      'page': effectivePage,
      'perPage': perPage,
      ..._sectionVariables(section),
    };
    final data = await _client.query(
      AniListQueries.mediaList,
      variables: variables,
    );
    final media =
        ((data['Page'] as Map<String, dynamic>?)?['media'] as List?) ??
        const [];
    return media
        .cast<Map<String, dynamic>>()
        .map(Anime.fromAniListMedia)
        .toList();
  }

  /// Search anime — bisa filter by [query], [genres], [year], [season],
  /// [format], atau kombinasi apa pun. Semua optional.
  ///
  /// **Behavior:**
  /// - Kalau semua filter kosong → return [] (tidak hit API)
  /// - Kombinasi filter di-AND di server (mis. `genre=Romance + year=2024`)
  ///
  /// **Format AniList API yang harus di-respect:**
  /// - [season] valid: `WINTER`, `SPRING`, `SUMMER`, `FALL`
  /// - [format] valid: `TV`, `TV_SHORT`, `MOVIE`, `OVA`, `ONA`, `SPECIAL`, `MUSIC`
  Future<List<Anime>> search(
    String query, {
    int page = 1,
    int perPage = 25,
    List<String> genres = const [],
    int? year,
    String? season,
    String? format,
    String? status,
    List<String>? sort,
  }) async {
    final trimmedQuery = query.trim();
    final hasQuery = trimmedQuery.isNotEmpty;
    final hasGenres = genres.isNotEmpty;
    final hasYear = year != null;
    final hasSeason = season != null && season.isNotEmpty;
    final hasFormat = format != null && format.isNotEmpty;
    final hasStatus = status != null && status.isNotEmpty;
    if (!hasQuery &&
        !hasGenres &&
        !hasYear &&
        !hasSeason &&
        !hasFormat &&
        !hasStatus) {
      return const [];
    }

    // **Dua query terpisah** — `mediaSearch` (text) atau `mediaBrowse` (filter).
    // Sebelumnya unified query bikin AniList return 0 result karena variable
    // schema mismatch. Pisah jadi lebih reliable.
    //
    // Strategy: kalau ada query text → utamakan mediaSearch (filter di-ignore).
    // Kalau hanya filter → mediaBrowse.
    if (hasQuery) {
      final vars = <String, dynamic>{
        'page': page,
        'perPage': perPage,
        'search': trimmedQuery, // sudah di-trim
        if (hasStatus) 'status': status,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
      };
      debugPrint('🔍 mediaSearch vars: $vars');
      final data = await _client.query(
        AniListQueries.mediaSearch,
        variables: vars,
        fetchPolicy: FetchPolicy.noCache,
      );
      final media =
          ((data['Page'] as Map<String, dynamic>?)?['media'] as List?) ??
          const [];
      debugPrint('🔍 mediaSearch result: ${media.length} items');
      return media
          .cast<Map<String, dynamic>>()
          .map(Anime.fromAniListMedia)
          .toList();
    }

    // Pure filter browse (no text).
    final vars = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      if (hasGenres) 'genre_in': genres,
      if (hasYear) 'seasonYear': year,
      if (hasSeason) 'season': season,
      if (hasFormat) 'format_in': [format],
      if (hasStatus) 'status': status,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    };
    debugPrint('🔍 mediaBrowse vars: $vars');
    final data = await _client.query(
      AniListQueries.mediaBrowse,
      variables: vars,
      fetchPolicy: FetchPolicy.noCache,
    );
    final media =
        ((data['Page'] as Map<String, dynamic>?)?['media'] as List?) ??
        const [];
    debugPrint('🔍 mediaBrowse result: ${media.length} items');
    return media
        .cast<Map<String, dynamic>>()
        .map(Anime.fromAniListMedia)
        .toList();
  }

  Future<Anime> getDetail(int id) async {
    final data = await _client.query(
      AniListQueries.mediaDetail,
      variables: {'id': id},
    );
    final media = data['Media'] as Map<String, dynamic>;
    return Anime.fromAniListMedia(media);
  }

  Map<String, dynamic> _sectionVariables(DiscoverSection section) {
    switch (section) {
      case DiscoverSection.trending:
        return {
          'sort': ['TRENDING_DESC', 'POPULARITY_DESC'],
        };
      case DiscoverSection.popular:
        return {
          'sort': ['POPULARITY_DESC'],
          'status': 'RELEASING',
        };
      case DiscoverSection.topRated:
        return {
          'sort': ['SCORE_DESC'],
        };
      case DiscoverSection.upcoming:
        return {
          'sort': ['POPULARITY_DESC'],
          'status': 'NOT_YET_RELEASED',
        };
      case DiscoverSection.completed:
        return {
          'sort': ['POPULARITY_DESC'],
          'status': 'FINISHED',
        };
    }
  }
}

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnimeRepository(ref.watch(anilistClientProvider)),
);
