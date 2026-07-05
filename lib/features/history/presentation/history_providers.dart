import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/history_entry.dart';
import '../data/history_repository.dart';

/// Stream perubahan history box — provider lain bisa watch ini untuk auto-refresh.
final historyChangesProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(historyRepositoryProvider);
  return repo.watch();
});

/// Recent watched untuk section "Continue Watching" di Home.
final recentWatchedProvider = Provider.autoDispose<List<HistoryEntry>>((ref) {
  ref.watch(historyChangesProvider); // re-evaluate when box changes
  final repo = ref.watch(historyRepositoryProvider);
  return repo.recentWatched(limit: 10);
});

/// All history entries (1 per episode, deduplicated by latest watchedAt).
/// Dipakai untuk hitung stats akurat di Profile — total ep, total jam.
final allHistoryProvider = Provider.autoDispose<List<HistoryEntry>>((ref) {
  ref.watch(historyChangesProvider);
  final repo = ref.watch(historyRepositoryProvider);
  // Hive box menyimpan 1 entry per (animeId:episodeId) — sudah unique.
  // Ambil semua via box values, dedupe pakai storage key.
  final seen = <String, HistoryEntry>{};
  for (final raw in repo.allEntriesRaw()) {
    final entry = HistoryEntry.fromJson(raw);
    final key = HistoryEntry.storageKey(entry.animeId, entry.episodeId);
    final existing = seen[key];
    if (existing == null || entry.watchedAt.isAfter(existing.watchedAt)) {
      seen[key] = entry;
    }
  }
  return seen.values.toList();
});

/// SEMUA entry (1 per episode) urut terbaru dulu — untuk layar Riwayat
/// Menonton (timeline grouped by tanggal + single/multi delete).
final allHistorySortedProvider = Provider.autoDispose<List<HistoryEntry>>((
  ref,
) {
  ref.watch(historyChangesProvider);
  final repo = ref.watch(historyRepositoryProvider);
  return repo.allEntries();
});

/// Latest history untuk anime tertentu (untuk Resume button di Detail).
final latestHistoryForAnimeProvider = Provider.autoDispose
    .family<HistoryEntry?, int>((ref, animeId) {
      ref.watch(historyChangesProvider);
      final repo = ref.watch(historyRepositoryProvider);
      return repo.latestForAnime(animeId);
    });

/// Map episodeId → fraction progress (0.0–1.0) untuk anime tertentu.
/// Dipakai untuk render progress bar tipis di tile episode picker.
final episodeProgressProvider = Provider.autoDispose
    .family<Map<String, double>, int>((ref, animeId) {
      ref.watch(historyChangesProvider);
      final repo = ref.watch(historyRepositoryProvider);
      final result = <String, double>{};
      for (final entry in repo.allForAnime(animeId)) {
        final frac = entry.progressFraction;
        if (frac != null && frac > 0) result[entry.episodeId] = frac;
      }
      return result;
    });

/// Set episode ID yang sudah ditonton untuk anime tertentu.
///
/// Threshold: >= 30 detik atau `isFinished`. Ini supaya tap-langsung-keluar
/// tidak otomatis bikin checkmark — perlu watch sebentar dulu.
final watchedEpisodeIdsProvider = Provider.autoDispose.family<Set<String>, int>(
  (ref, animeId) {
    ref.watch(historyChangesProvider);
    final repo = ref.watch(historyRepositoryProvider);
    final result = <String>{};
    for (final entry in repo.allForAnime(animeId)) {
      if (entry.positionSeconds >= 30 || entry.isFinished) {
        result.add(entry.episodeId);
      }
    }
    return result;
  },
);
