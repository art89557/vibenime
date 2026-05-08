import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../shared/models/episode.dart';
import '../../../shared/models/stream_source.dart';

/// Abstraksi sumber streaming. Di MVP punya 2 mode:
/// 1. **YouTube trailer** dari AniList — kalau anime punya trailer official,
///    play itu (visual matching judul anime)
/// 2. **Sample HLS** (Mux Big Buck Bunny) — fallback kalau anime tidak punya trailer
///
/// Production deployment bisa swap implementation dengan provider berlisensi
/// (Crunchyroll, Bilibili) tanpa mengubah konsumer.
abstract class StreamingRepository {
  /// Sintesa list episode dari `episodeCount` AniList (atau fallback 12).
  List<Episode> buildEpisodes({
    required int anilistId,
    required int? episodeCount,
  });

  /// Ambil payload streaming. Kalau `youtubeTrailerId` ada, return YouTube payload.
  /// Kalau tidak, fallback ke sample HLS.
  Future<StreamPayload> fetchStream({
    required String episodeId,
    String? youtubeTrailerId,
  });
}

/// Implementasi sample untuk MVP & demo tugas.
///
/// Strategi:
/// - **Prefer YouTube trailer** dari AniList → visual matching judul anime
/// - **Fallback Mux HLS** → kalau anime tidak punya trailer
///
/// Trade-off untuk MVP: trailer = sama untuk semua episode anime tsb. Acceptable
/// untuk demo akademik; production butuh integrasi provider berlisensi.
class SampleStreamingRepository implements StreamingRepository {
  const SampleStreamingRepository();

  @override
  List<Episode> buildEpisodes({
    required int anilistId,
    required int? episodeCount,
  }) {
    final count = episodeCount ?? 12;
    return List.generate(count, (i) {
      final number = i + 1;
      return Episode(
        id: 'sample-$anilistId-ep-$number',
        number: number,
        title: 'Episode $number',
      );
    });
  }

  @override
  Future<StreamPayload> fetchStream({
    required String episodeId,
    String? youtubeTrailerId,
  }) async {
    // Simulasi latency network biar UX-nya realistis saat demo.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Mode 1: YouTube trailer (preferred jika tersedia).
    if (youtubeTrailerId != null && youtubeTrailerId.isNotEmpty) {
      return StreamPayload(youtubeVideoId: youtubeTrailerId);
    }

    // Mode 2: Sample HLS fallback.
    return StreamPayload(
      sources: [
        StreamSource(
          url: Env.sampleStreamUrl,
          type: 'hls',
          quality: 'auto',
        ),
      ],
      subtitles: const [
        SubtitleTrack(
          url: 'https://test-streams.mux.dev/captions/captions_en.vtt',
          language: 'English',
        ),
      ],
    );
  }
}

final streamingRepositoryProvider = Provider<StreamingRepository>(
  (ref) => const SampleStreamingRepository(),
);
