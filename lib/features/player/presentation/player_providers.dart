import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/stream_source.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../data/streaming_repository.dart';

/// Tuple parameter untuk streamPayloadProvider — butuh animeId + episodeId
/// supaya bisa lookup trailer YouTube dari AniList.
typedef StreamArgs = ({int animeId, String episodeId});

final streamPayloadProvider = FutureProvider.family
    .autoDispose<StreamPayload, StreamArgs>((ref, args) async {
  final repo = ref.watch(streamingRepositoryProvider);

  // Fetch trailer ID dari anime detail (cached lewat animeDetailProvider).
  String? trailerId;
  try {
    final anime = await ref.watch(animeDetailProvider(args.animeId).future);
    trailerId = anime.trailerYoutubeId;
  } catch (_) {
    // Detail gagal load? Tetap lanjut dengan fallback HLS.
    trailerId = null;
  }

  return repo.fetchStream(
    episodeId: args.episodeId,
    youtubeTrailerId: trailerId,
  );
});
