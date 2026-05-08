import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/anime.dart';
import '../../discover/data/anime_repository.dart';

/// State input search (raw, sebelum debounce).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search result — auto-fetch saat query berubah, dengan debounce 350ms.
/// Saat user mengetik cepat, provider lama di-dispose sebelum future-nya selesai
/// (autoDispose), jadi cuma query final yang sampai ke API.
final searchResultsProvider =
    FutureProvider.autoDispose<List<Anime>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return const [];

  // Debounce: tunggu 350ms; kalau provider sudah di-dispose (query baru masuk),
  // throw CancelledException — Riverpod akan ignore karena provider sudah hilang.
  final completer = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 350), completer.complete);
  ref.onDispose(() {
    timer.cancel();
    if (!completer.isCompleted) {
      completer.completeError(StateError('cancelled'));
    }
  });
  await completer.future;

  final repo = ref.watch(animeRepositoryProvider);
  return repo.search(query, perPage: 30);
});
