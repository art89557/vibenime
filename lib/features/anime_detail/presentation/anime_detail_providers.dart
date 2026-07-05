import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/anime.dart';
import '../../../shared/models/episode.dart';
import '../../discover/data/anime_repository.dart';
import '../../player/data/streaming_repository.dart';

final animeDetailProvider = FutureProvider.family.autoDispose<Anime, int>((
  ref,
  id,
) async {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.getDetail(id);
});

/// Episode list — disintesa dari `episodeCount` AniList lewat StreamingRepository.
final animeEpisodesProvider = FutureProvider.family
    .autoDispose<List<Episode>, int>((ref, id) async {
      final detail = await ref.watch(animeDetailProvider(id).future);
      final streaming = ref.watch(streamingRepositoryProvider);
      return streaming.buildEpisodes(
        anilistId: id,
        episodeCount: detail.episodes,
      );
    });
