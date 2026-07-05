import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';
import '../../../shared/models/anime.dart';
import 'favorite_entry.dart';

/// Hive-backed local "My List" storage.
///
/// Pattern follow `HistoryRepository` (lib/features/history/data) — single
/// box, stream watcher. Tidak butuh akun.
///
/// Entry punya `WatchStatus` (planning / watching / completed) + total
/// episodes snapshot untuk render progress bar tanpa fetch ulang AniList.
class FavoritesRepository {
  FavoritesRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  /// Tambah baru atau update status entry existing.
  ///
  /// Kalau entry sudah ada: preserve `addedAt`, update `status` &
  /// `totalEpisodes`. Kalau belum ada: create entry baru.
  Future<void> addOrUpdate(Anime anime, WatchStatus status) async {
    final key = FavoriteEntry.storageKey(anime.id);
    final existing = getEntry(anime.id);
    final entry = existing != null
        ? existing.copyWith(
            status: status,
            totalEpisodes: anime.episodes ?? existing.totalEpisodes,
          )
        : FavoriteEntry(
            animeId: anime.id,
            title: anime.title,
            coverImage: anime.coverImage,
            addedAt: DateTime.now(),
            status: status,
            totalEpisodes: anime.episodes,
          );
    await _box.put(key, entry.toJson());
  }

  /// Update status saja untuk entry yang sudah ada. No-op kalau belum
  /// ada (auto-promoter butuh idempotent — tidak boleh inject anime baru).
  Future<void> setStatus(int animeId, WatchStatus status) async {
    final existing = getEntry(animeId);
    if (existing == null) return;
    if (existing.status == status) return; // skip redundant write
    await _box.put(
      FavoriteEntry.storageKey(animeId),
      existing.copyWith(status: status).toJson(),
    );
  }

  /// Convenience: tap "+" di card → kalau belum ada add sebagai Planning,
  /// kalau sudah ada → remove. Return true kalau setelah action sekarang
  /// ada di list, false kalau di-remove. Match old `toggle` semantic.
  Future<bool> toggle(Anime anime) async {
    final key = FavoriteEntry.storageKey(anime.id);
    if (_box.containsKey(key)) {
      await _box.delete(key);
      return false;
    }
    await addOrUpdate(anime, WatchStatus.planning);
    return true;
  }

  /// Ambil entry untuk anime tertentu.
  FavoriteEntry? getEntry(int animeId) {
    final raw = _box.get(FavoriteEntry.storageKey(animeId));
    if (raw == null) return null;
    return FavoriteEntry.fromJson(raw);
  }

  /// True kalau anime ada di list (status apapun).
  bool isFavorite(int animeId) =>
      _box.containsKey(FavoriteEntry.storageKey(animeId));

  /// Hapus dari list. No-op kalau tidak ada.
  Future<void> remove(int animeId) async {
    await _box.delete(FavoriteEntry.storageKey(animeId));
  }

  /// Semua entry, sorted newest first.
  List<FavoriteEntry> getAll() {
    final all = _box.values.map(FavoriteEntry.fromJson).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return all;
  }

  /// Filter entry by status. Null = semua.
  List<FavoriteEntry> getByStatus(WatchStatus? status) {
    final all = getAll();
    if (status == null) return all;
    return all.where((e) => e.status == status).toList();
  }

  /// Stream emit on every box change.
  Stream<List<FavoriteEntry>> watchAll() async* {
    yield getAll();
    await for (final _ in _box.watch()) {
      yield getAll();
    }
  }

  Future<void> clear() => _box.clear();
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final box = Hive.box<Map<dynamic, dynamic>>(HiveBoxes.favorites);
  return FavoritesRepository(box);
});
