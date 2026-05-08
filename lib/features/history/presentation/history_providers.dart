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

/// Latest history untuk anime tertentu (untuk Resume button di Detail).
final latestHistoryForAnimeProvider =
    Provider.autoDispose.family<HistoryEntry?, int>((ref, animeId) {
  ref.watch(historyChangesProvider);
  final repo = ref.watch(historyRepositoryProvider);
  return repo.latestForAnime(animeId);
});
