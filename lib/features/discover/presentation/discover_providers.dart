import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/anime.dart';
import '../data/anime_repository.dart';

/// State pagination per section. Halaman trending/popular/topRated/upcoming
/// punya state independent — bisa scroll lebih jauh di trending sambil
/// upcoming masih di page 1.
class PaginatedAnimeState {
  const PaginatedAnimeState({
    this.items = const [],
    this.page = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<Anime> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  PaginatedAnimeState copyWith({
    List<Anime>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return PaginatedAnimeState(
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaginatedAnimeNotifier extends StateNotifier<PaginatedAnimeState> {
  PaginatedAnimeNotifier(this._repo, this._section)
    : super(const PaginatedAnimeState()) {
    loadInitial();
  }

  final AnimeRepository _repo;
  final DiscoverSection _section;

  static const int _perPage = 12;

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _repo.fetchSection(
        _section,
        page: 1,
        perPage: _perPage,
      );
      state = state.copyWith(
        items: items,
        page: 1,
        isLoading: false,
        hasMore: items.length >= _perPage,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Dipanggil dari scroll listener saat user dekat bottom. Idempotent —
  /// kalau sudah loadingMore atau hasMore=false, no-op.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final nextPage = state.page + 1;
      final more = await _repo.fetchSection(
        _section,
        page: nextPage,
        perPage: _perPage,
      );
      state = state.copyWith(
        items: [...state.items, ...more],
        page: nextPage,
        isLoadingMore: false,
        hasMore: more.length >= _perPage,
      );
    } catch (e) {
      debugPrint('loadMore failed: $e');
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<void> refresh() => loadInitial();
}

/// Paginated provider — pakai ini di home screen kalau butuh infinite scroll.
/// Untuk section preview (8-12 item dengan tombol "Lihat semua"), tetap
/// pakai [discoverSectionProvider] di bawah.
final paginatedDiscoverProvider = StateNotifierProvider.family
    .autoDispose<PaginatedAnimeNotifier, PaginatedAnimeState, DiscoverSection>((
      ref,
      section,
    ) {
      final repo = ref.watch(animeRepositoryProvider);
      return PaginatedAnimeNotifier(repo, section);
    });

/// Legacy provider — masih dipakai untuk section preview di Home (top-12 saja,
/// tidak infinite scroll). Tetap di-export biar tidak break existing UI.
final discoverSectionProvider = FutureProvider.family
    .autoDispose<List<Anime>, DiscoverSection>((ref, section) async {
      final repo = ref.watch(animeRepositoryProvider);
      return repo.fetchSection(section, perPage: 12);
    });
