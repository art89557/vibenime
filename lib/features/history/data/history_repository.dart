import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';
import 'history_entry.dart';

class HistoryRepository {
  HistoryRepository(this._box);

  final Box<Map<dynamic, dynamic>> _box;

  /// Simpan / update progress untuk satu episode.
  Future<void> save(HistoryEntry entry) async {
    final key = HistoryEntry.storageKey(entry.animeId, entry.episodeId);
    await _box.put(key, entry.toJson());
  }

  /// Ambil progress untuk satu episode tertentu.
  HistoryEntry? get(int animeId, String episodeId) {
    final key = HistoryEntry.storageKey(animeId, episodeId);
    final raw = _box.get(key);
    if (raw == null) return null;
    return HistoryEntry.fromJson(raw);
  }

  /// Latest entry untuk anime tertentu — untuk fitur "Resume" di Detail.
  HistoryEntry? latestForAnime(int animeId) {
    HistoryEntry? latest;
    for (final raw in _box.values) {
      if (raw['animeId'] != animeId) continue;
      final entry = HistoryEntry.fromJson(raw);
      if (latest == null || entry.watchedAt.isAfter(latest.watchedAt)) {
        latest = entry;
      }
    }
    return latest;
  }

  /// Semua entry untuk anime tertentu (per episode). Dipakai oleh
  /// `watchedEpisodeIdsProvider` untuk render checkmark di episode grid.
  List<HistoryEntry> allForAnime(int animeId) {
    final result = <HistoryEntry>[];
    for (final raw in _box.values) {
      if (raw['animeId'] != animeId) continue;
      result.add(HistoryEntry.fromJson(raw));
    }
    return result;
  }

  /// Recent watched — 1 entry per anime (yang paling terakhir), sorted by waktu.
  /// Dipakai untuk section "Continue Watching" di Home.
  List<HistoryEntry> recentWatched({int limit = 10}) {
    final byAnime = <int, HistoryEntry>{};
    for (final raw in _box.values) {
      final entry = HistoryEntry.fromJson(raw);
      final existing = byAnime[entry.animeId];
      if (existing == null || entry.watchedAt.isAfter(existing.watchedAt)) {
        byAnime[entry.animeId] = entry;
      }
    }
    final sorted = byAnime.values.toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return sorted.take(limit).toList();
  }

  /// SEMUA entry (1 per episode), urut terbaru dulu — untuk layar Riwayat
  /// Menonton (timeline grouped by tanggal).
  List<HistoryEntry> allEntries() {
    final list = _box.values.map(HistoryEntry.fromJson).toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return list;
  }

  /// Hapus 1 entry (1 episode) dari history.
  Future<void> delete(int animeId, String episodeId) =>
      _box.delete(HistoryEntry.storageKey(animeId, episodeId));

  /// Hapus banyak entry sekaligus via storage key (multi-select di Riwayat).
  Future<void> deleteKeys(Iterable<String> keys) => _box.deleteAll(keys);

  /// Tandai 1 episode sebagai selesai ditonton (set posisi = durasi → checkmark
  /// + isFinished true). No-op kalau durasi belum diketahui.
  Future<void> markFinished(HistoryEntry entry) async {
    final dur = entry.durationSeconds;
    if (dur == null) return;
    await save(
      HistoryEntry(
        animeId: entry.animeId,
        episodeId: entry.episodeId,
        episodeNumber: entry.episodeNumber,
        positionSeconds: dur,
        durationSeconds: dur,
        watchedAt: DateTime.now(),
      ),
    );
  }

  /// Stream perubahan box → trigger UI rebuild.
  Stream<void> watch() => _box.watch().map((_) {});

  /// Raw access ke semua values di box — untuk provider yang butuh
  /// hitung agregat (mis. profile stats total jam tonton).
  Iterable<Map<dynamic, dynamic>> allEntriesRaw() => _box.values;

  Future<void> clear() => _box.clear();
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final box = Hive.box<Map<dynamic, dynamic>>(HiveBoxes.history);
  return HistoryRepository(box);
});
