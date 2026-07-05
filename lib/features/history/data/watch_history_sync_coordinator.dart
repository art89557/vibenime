import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';
import '../presentation/history_providers.dart';
import 'history_entry.dart';
import 'history_repository.dart';
import 'watch_history_sync_repository.dart';

/// Mengkoordinir sinkron dua-arah progress nonton lokal (Hive) ↔ cloud
/// (Supabase). Konflik di-resolve **last-write-wins** by `watchedAt`.
///
/// - [syncNow]: pull remote → merge ke lokal → push delta lokal → simpan
///   `lastSyncAt`. Dipanggil saat app-launch & setelah login.
/// - Push berkelanjutan: dengar perubahan history box, debounce ~3 dtk, lalu
///   push entry yang lebih baru dari `lastSyncAt`.
class WatchHistorySyncCoordinator {
  WatchHistorySyncCoordinator(this._ref);

  final Ref _ref;
  Timer? _debounce;
  bool _syncing = false;

  static const _lastSyncKey = 'watch_history_last_sync';

  /// Sinkron penuh dua-arah. No-op kalau Supabase belum siap / belum login.
  Future<void> syncNow() async {
    final remote = _ref.read(watchHistorySyncRepositoryProvider);
    if (!remote.isAvailable || _syncing) return;
    _syncing = true;
    try {
      final local = _ref.read(historyRepositoryProvider);
      final remoteEntries = await remote.pullAll();
      final localEntries = local.allEntries();

      final plan = planMerge(local: localEntries, remote: remoteEntries);

      // Remote lebih baru / lokal belum punya → tulis ke Hive.
      for (final r in plan.toWriteLocal) {
        await local.save(r);
      }
      // Lokal lebih baru / remote belum punya → push.
      await remote.pushEntries(plan.toPush);

      _setLastSync(DateTime.now());
    } catch (e) {
      debugPrint('syncWatchHistory failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Dipanggil saat history box berubah → jadwalkan push delta (debounced).
  void onHistoryChanged() {
    if (!_ref.read(watchHistorySyncRepositoryProvider).isAvailable) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), _pushDelta);
  }

  Future<void> _pushDelta() async {
    final remote = _ref.read(watchHistorySyncRepositoryProvider);
    if (!remote.isAvailable) return;
    final last = _lastSync();
    final delta = _ref
        .read(historyRepositoryProvider)
        .allEntries()
        .where((e) => last == null || e.watchedAt.isAfter(last))
        .toList();
    if (delta.isEmpty) return;
    await remote.pushEntries(delta);
    _setLastSync(DateTime.now());
  }

  DateTime? _lastSync() {
    final ms = Hive.box<dynamic>(HiveBoxes.settings).get(_lastSyncKey) as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  void _setLastSync(DateTime t) {
    Hive.box<dynamic>(
      HiveBoxes.settings,
    ).put(_lastSyncKey, t.millisecondsSinceEpoch);
  }

  void dispose() => _debounce?.cancel();
}

/// Hasil keputusan merge: apa yang harus ditulis ke lokal & apa yang di-push.
class WatchHistoryMergePlan {
  const WatchHistoryMergePlan({
    required this.toWriteLocal,
    required this.toPush,
  });

  /// Entry remote yang lebih baru / belum ada di lokal → simpan ke Hive.
  final List<HistoryEntry> toWriteLocal;

  /// Entry lokal yang lebih baru / belum ada di remote → push ke cloud.
  final List<HistoryEntry> toPush;
}

/// Keputusan merge **last-write-wins** by `watchedAt` (pure, tanpa I/O →
/// mudah di-unit-test). Per episode (key = `animeId:episodeId`):
/// - remote menang (lebih baru / lokal tak punya) → masuk `toWriteLocal`.
/// - lokal menang (lebih baru / remote tak punya) → masuk `toPush`.
/// - `watchedAt` sama → tak ada aksi (sudah sinkron).
WatchHistoryMergePlan planMerge({
  required List<HistoryEntry> local,
  required List<HistoryEntry> remote,
}) {
  String keyOf(HistoryEntry e) =>
      HistoryEntry.storageKey(e.animeId, e.episodeId);
  final localByKey = {for (final e in local) keyOf(e): e};
  final remoteByKey = {for (final e in remote) keyOf(e): e};

  final toWriteLocal = <HistoryEntry>[];
  for (final r in remote) {
    final l = localByKey[keyOf(r)];
    if (l == null || r.watchedAt.isAfter(l.watchedAt)) toWriteLocal.add(r);
  }

  final toPush = <HistoryEntry>[];
  for (final l in local) {
    final r = remoteByKey[keyOf(l)];
    if (r == null || l.watchedAt.isAfter(r.watchedAt)) toPush.add(l);
  }

  return WatchHistoryMergePlan(toWriteLocal: toWriteLocal, toPush: toPush);
}

/// Coordinator hidup selama sesi + dengar perubahan history untuk push delta.
/// Di-`watch` dari shell/Home supaya tetap alive.
final watchHistorySyncCoordinatorProvider =
    Provider<WatchHistorySyncCoordinator>((ref) {
      final coord = WatchHistorySyncCoordinator(ref);
      ref.listen(historyChangesProvider, (_, _) => coord.onHistoryChanged());
      ref.onDispose(coord.dispose);
      return coord;
    });

/// Helper dari widget (Home initState / setelah login) — pull→merge→push.
Future<void> syncWatchHistory(WidgetRef ref) =>
    ref.read(watchHistorySyncCoordinatorProvider).syncNow();
