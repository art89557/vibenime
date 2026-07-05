import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';
import '../../../shared/models/anime.dart';
import '../../discover/data/anime_repository.dart';

/// State input search (raw, sebelum debounce).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Repository tipis untuk persist search history di Hive box.
class SearchHistoryRepository {
  SearchHistoryRepository(this._box);
  final Box<String> _box;

  static const _maxItems = 10;

  /// Daftar query terbaru (newest first).
  List<String> getAll() {
    final values = _box.values.toList();
    return values.reversed
        .toList(); // box urut insertion, balik biar latest atas
  }

  /// Tambah query baru. Dedupe (kalau query sama, hapus yang lama dulu).
  /// Trim ke [_maxItems] entry terbaru.
  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return; // skip terlalu pendek

    // Dedupe — cari key dengan value sama, hapus
    for (final entry in _box.toMap().entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        await _box.delete(entry.key);
      }
    }

    await _box.add(trimmed);

    // Trim — kalau >max, hapus yang paling lama
    while (_box.length > _maxItems) {
      final oldestKey = _box.keys.first;
      await _box.delete(oldestKey);
    }
  }

  Future<void> remove(String query) async {
    for (final entry in _box.toMap().entries) {
      if (entry.value == query) {
        await _box.delete(entry.key);
      }
    }
  }

  Future<void> clearAll() async => _box.clear();
}

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return SearchHistoryRepository(Hive.box<String>(HiveBoxes.searchHistory));
});

/// Stream provider — emit list history setiap box change.
final searchHistoryProvider = StreamProvider<List<String>>((ref) {
  final repo = ref.watch(searchHistoryRepositoryProvider);
  final box = Hive.box<String>(HiveBoxes.searchHistory);
  return Stream<List<String>>.multi((controller) {
    controller.add(repo.getAll());
    final sub = box.watch().listen((_) {
      if (!controller.isClosed) controller.add(repo.getAll());
    });
    controller.onCancel = () => sub.cancel();
  });
});

/// State genre filter aktif. Kosong = no filter.
///
/// Di-set lewat `GenrePickerScreen` (return value dari `context.push`).
/// Bisa juga di-clear via chip "x" di header search.
final selectedGenresProvider = StateProvider<List<String>>((ref) => const []);

/// State filter tahun rilis. Null = no filter.
final selectedYearProvider = StateProvider<int?>((ref) => null);

/// State filter musim rilis. Valid: `WINTER`, `SPRING`, `SUMMER`, `FALL`.
/// Null = no filter.
final selectedSeasonProvider = StateProvider<String?>((ref) => null);

/// State filter format. Valid: `TV`, `TV_SHORT`, `MOVIE`, `OVA`, `ONA`,
/// `SPECIAL`, `MUSIC`. Null = no filter.
final selectedFormatProvider = StateProvider<String?>((ref) => null);

/// State filter airing status. Valid AniList enum: `RELEASING`, `FINISHED`,
/// `NOT_YET_RELEASED`, `CANCELLED`, `HIATUS`. Null = no filter.
final selectedAiringStatusProvider = StateProvider<String?>((ref) => null);

/// State sort yang aktif. Default: POPULARITY_DESC (paling populer).
///
/// Valid AniList enum:
/// - `TITLE_ROMAJI` (alfabetis)
/// - `POPULARITY_DESC` (default)
/// - `SCORE_DESC` (skor tertinggi)
/// - `TRENDING_DESC` (sedang ramai)
/// - `FAVOURITES_DESC` (paling banyak di-favorit di AniList)
/// - `UPDATED_AT_DESC` (terbaru ditambah/diperbarui katalog)
/// - `START_DATE_DESC` (rilis terbaru)
final sortProvider = StateProvider<String>((ref) => 'POPULARITY_DESC');

/// View mode untuk grid result di Search screen.
enum SearchViewMode { compact, large, list }

final viewModeProvider = StateProvider<SearchViewMode>(
  (ref) => SearchViewMode.large,
);

/// True kalau ada filter aktif (selain query text).
bool _hasAnyFilter({
  required List<String> genres,
  required int? year,
  required String? season,
  required String? format,
  required String? status,
}) {
  return genres.isNotEmpty ||
      year != null ||
      (season != null && season.isNotEmpty) ||
      (format != null && format.isNotEmpty) ||
      (status != null && status.isNotEmpty);
}

/// Search result — auto-fetch saat query/filter berubah, debounce 350ms.
///
/// **Logika trigger:**
/// - Query >= 2 char OR salah satu filter aktif → fetch
/// - Selain itu → return [] (default state)
///
/// Saat user mengetik cepat, provider lama di-dispose sebelum future-nya selesai
/// (autoDispose), jadi cuma query final yang sampai ke API.
final searchResultsProvider = FutureProvider.autoDispose<List<Anime>>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider).trim();
  final genres = ref.watch(selectedGenresProvider);
  final year = ref.watch(selectedYearProvider);
  final season = ref.watch(selectedSeasonProvider);
  final format = ref.watch(selectedFormatProvider);
  final status = ref.watch(selectedAiringStatusProvider);
  final sort = ref.watch(sortProvider);

  final hasQuery = query.length >= 2;
  final hasFilter = _hasAnyFilter(
    genres: genres,
    year: year,
    season: season,
    format: format,
    status: status,
  );

  // Trigger fetch hanya kalau ada query atau filter aktif.
  if (!hasQuery && !hasFilter) return const [];

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
  return repo.search(
    hasQuery ? query : '',
    genres: genres,
    year: year,
    season: season,
    format: format,
    status: status,
    sort: [sort],
    perPage: 30,
  );
});
