import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/stream_source.dart';
import '../../anime_detail/presentation/anime_detail_providers.dart';
import '../../downloads/data/download_repository.dart';
import '../data/streaming_repository.dart';

/// State source yang dipilih user manual via dropdown di player.
///
/// Null = pakai default urutan (priority dari repository). Saat user pilih
/// di dropdown, set sourceId disini → consumer (player_screen) re-sort
/// payload list supaya source pilihan user di index 0.
///
/// Key by animeId supaya pilihan persist per-anime selama session.
final selectedSourceProvider = StateProvider.family<String?, int>(
  (ref, animeId) => null,
);

/// Tuple parameter untuk [streamPayloadsProvider] — kombinasi animeId
/// dan episodeId (Riverpod family pakai single param, jadi pakai record).
typedef StreamArgs = ({int animeId, String episodeId});

/// Async provider yang return **ordered list** of [StreamPayload] candidates
/// untuk player coba.
///
/// Player consume list ini, mulai dari index 0. Kalau payload[0] gagal load
/// (mis. YouTube error 150), player switch ke payload[1], dst. List dijamin
/// non-empty (minimum ada Mux fallback).
///
/// Workflow internal:
/// 1. Fetch [animeEpisodesProvider] untuk dapat episode number (dari id)
/// 2. Fetch [animeDetailProvider] untuk dapat trailer YouTube ID
/// 3. Delegate ke [StreamingRepository.fetchPayloads]
///
/// ```dart
/// final payloads = await ref.watch(
///   streamPayloadsProvider((animeId: 4082, episodeId: 'ep-4082-1')).future,
/// );
/// // [StreamPayload, StreamPayload, ...] sorted by priority
/// ```
final streamPayloadsProvider = FutureProvider.family
    .autoDispose<List<StreamPayload>, StreamArgs>((ref, args) async {
      final repo = ref.watch(streamingRepositoryProvider);

      // Cari episode number dari list episodes (cached lewat animeEpisodesProvider).
      int episodeNumber = 1;
      try {
        final eps = await ref.watch(animeEpisodesProvider(args.animeId).future);
        final found = eps.where((e) => e.id == args.episodeId).toList();
        if (found.isNotEmpty) episodeNumber = found.first.number;
      } catch (_) {
        // Default ke 1 kalau gagal load.
      }

      // Fetch trailer ID + judul dari anime detail (untuk Layer 2 & search Indo).
      String? trailerId;
      String animeTitle = '';
      var altTitles = const <String>[];
      try {
        final anime = await ref.watch(animeDetailProvider(args.animeId).future);
        trailerId = anime.trailerYoutubeId;
        // Prefer englishTitle untuk match situs Indo (banyak pakai judul EN),
        // fallback ke title (romaji/english/native gabungan).
        animeTitle = (anime.englishTitle?.isNotEmpty ?? false)
            ? anime.englishTitle!
            : anime.title;
        // Judul alternatif (romaji/native/title) — dicoba kalau judul utama
        // tak ketemu di situs Indo. Dedupe + buang yang sama dengan animeTitle.
        altTitles = <String>[
          anime.romajiTitle ?? '',
          anime.nativeTitle ?? '',
          anime.title,
        ].where((t) => t.isNotEmpty && t != animeTitle).toSet().toList();
      } catch (_) {
        trailerId = null;
      }

      final payloads = await repo.fetchPayloads(
        anilistId: args.animeId,
        episodeNumber: episodeNumber,
        episodeId: args.episodeId,
        youtubeTrailerId: trailerId,
        animeTitle: animeTitle,
        altTitles: altTitles,
      );

      // Reorder payload supaya source yang user pilih di dropdown (kalau ada)
      // jadi di index 0. Player coba dari index 0 → kalau gagal lanjut ke next.
      final preferred = ref.watch(selectedSourceProvider(args.animeId));
      final orderedPayloads = preferred == null
          ? payloads
          : _reorderByPreferred(payloads, preferred);

      // **Prepend local download payload kalau available** — supaya player
      // langsung play offline tanpa hit network. User-experience: kalau pernah
      // download, otomatis play offline (lebih hemat data + faster).
      final downloadEntry = ref
          .read(downloadRepositoryProvider)
          .get(args.animeId, args.episodeId);
      if (downloadEntry != null) {
        final localPayload = StreamPayload(
          sources: [StreamSource(url: downloadEntry.localPath, type: 'mp4')],
          sourceId: 'local_download',
          sourceLabel: 'Tersimpan Offline',
        );
        return [localPayload, ...orderedPayloads];
      }

      return orderedPayloads;
    });

/// Move payload dengan `sourceId == preferred` ke index 0, sisanya tetap
/// urut. Idempotent — kalau preferred tidak ada di list, return as-is.
List<StreamPayload> _reorderByPreferred(
  List<StreamPayload> payloads,
  String preferred,
) {
  final idx = payloads.indexWhere((p) => p.sourceId == preferred);
  if (idx <= 0) return payloads;
  return [
    payloads[idx],
    ...payloads.sublist(0, idx),
    ...payloads.sublist(idx + 1),
  ];
}
