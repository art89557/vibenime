import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../../shared/models/anime.dart';

enum DiscoverSection { trending, popular, topRated, upcoming }

class AnimeRepository {
  AnimeRepository(this._client);

  final AniListClient _client;

  Future<List<Anime>> fetchSection(DiscoverSection section,
      {int page = 1, int perPage = 20}) async {
    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      ..._sectionVariables(section),
    };
    final data = await _client.query(
      AniListQueries.mediaList,
      variables: variables,
    );
    final media = ((data['Page'] as Map<String, dynamic>?)?['media'] as List?) ?? const [];
    return media
        .cast<Map<String, dynamic>>()
        .map(Anime.fromAniListMedia)
        .toList();
  }

  Future<List<Anime>> search(String query,
      {int page = 1, int perPage = 25}) async {
    if (query.trim().isEmpty) return const [];
    final data = await _client.query(
      AniListQueries.mediaSearch,
      variables: {'search': query, 'page': page, 'perPage': perPage},
    );
    final media = ((data['Page'] as Map<String, dynamic>?)?['media'] as List?) ?? const [];
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
        return {'sort': ['TRENDING_DESC', 'POPULARITY_DESC']};
      case DiscoverSection.popular:
        return {
          'sort': ['POPULARITY_DESC'],
          'status': 'RELEASING',
        };
      case DiscoverSection.topRated:
        return {'sort': ['SCORE_DESC']};
      case DiscoverSection.upcoming:
        return {
          'sort': ['POPULARITY_DESC'],
          'status': 'NOT_YET_RELEASED',
        };
    }
  }
}

final animeRepositoryProvider = Provider<AnimeRepository>(
  (ref) => AnimeRepository(ref.watch(anilistClientProvider)),
);
