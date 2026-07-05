import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';
import 'favorite_entry.dart';
import 'favorites_repository.dart';
import 'favorites_sync_repository.dart';

/// Sinkron dua-arah favorit/My List lokal (Hive) ↔ cloud (Supabase).
///
/// Beda dari watch-history: **hapus harus ikut tersinkron** (favorit sering
/// di-remove). Tanpa tombstone, dipakai aproksimasi `lastSyncAt`:
/// - hanya-di-remote & `updatedAt <= lastSyncAt` → dihapus lokal setelah
///   sync terakhir → hapus di remote.
/// - hanya-di-lokal  & `updatedAt <= lastSyncAt` → dihapus di device lain →
///   hapus di lokal.
/// - sisanya: last-write-wins by `updatedAt` / union saat first-sync.
class FavoritesSyncCoordinator {
  FavoritesSyncCoordinator(this._ref);

  final Ref _ref;
  Timer? _debounce;
  bool _syncing = false;

  static const _lastSyncKey = 'favorites_last_sync';

  Future<void> syncNow() async {
    final remote = _ref.read(favoritesSyncRepositoryProvider);
    if (!remote.isAvailable || _syncing) return;
    _syncing = true;
    try {
      final local = _ref.read(favoritesRepositoryProvider);
      final remoteEntries = await remote.pullAll();
      final localEntries = local.getAll();

      final plan = planMergeFavorites(
        local: localEntries,
        remote: remoteEntries,
        lastSyncAt: _lastSync(),
      );

      for (final e in plan.toWriteLocal) {
        await local.saveRaw(e); // jangan bump updatedAt (nilai remote dipakai)
      }
      for (final id in plan.toDeleteLocal) {
        await local.remove(id);
      }
      await remote.pushEntries(plan.toPush);
      await remote.deleteEntries(plan.toDeleteRemote);

      _setLastSync(DateTime.now());
    } catch (e) {
      debugPrint('syncFavorites failed: $e');
    } finally {
      _syncing = false;
    }
  }

  /// Box favorit berubah → jadwalkan full-sync (debounced). Full-sync dipilih
  /// (bukan delta) karena hapus perlu dipropagasi & list favorit kecil.
  void onFavoritesChanged() {
    if (_syncing) return; // perubahan dari apply sync sendiri → abaikan
    if (!_ref.read(favoritesSyncRepositoryProvider).isAvailable) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), syncNow);
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

/// Hasil keputusan merge favorit.
class FavoritesMergePlan {
  const FavoritesMergePlan({
    required this.toWriteLocal,
    required this.toPush,
    required this.toDeleteLocal,
    required this.toDeleteRemote,
  });

  final List<FavoriteEntry> toWriteLocal;
  final List<FavoriteEntry> toPush;
  final List<int> toDeleteLocal;
  final List<int> toDeleteRemote;
}

/// Keputusan merge favorit (pure, tanpa I/O → mudah di-test).
///
/// Aturan per animeId:
/// - Ada di dua sisi → LWW by `updatedAt` (remote lebih baru → tulis lokal;
///   lokal lebih baru → push; seri → no-op).
/// - Hanya remote: [lastSyncAt] null (first sync) ATAU `updatedAt > lastSyncAt`
///   → entri baru dari device lain → tulis lokal. Selainnya → sudah dihapus
///   lokal setelah sync → hapus remote.
/// - Hanya lokal: [lastSyncAt] null ATAU `updatedAt > lastSyncAt` → entri
///   baru lokal → push. Selainnya → dihapus di device lain → hapus lokal.
FavoritesMergePlan planMergeFavorites({
  required List<FavoriteEntry> local,
  required List<FavoriteEntry> remote,
  DateTime? lastSyncAt,
}) {
  final localById = {for (final e in local) e.animeId: e};
  final remoteById = {for (final e in remote) e.animeId: e};

  bool isNewSince(FavoriteEntry e) =>
      lastSyncAt == null || e.updatedAt.isAfter(lastSyncAt);

  final toWriteLocal = <FavoriteEntry>[];
  final toPush = <FavoriteEntry>[];
  final toDeleteLocal = <int>[];
  final toDeleteRemote = <int>[];

  for (final r in remote) {
    final l = localById[r.animeId];
    if (l == null) {
      if (isNewSince(r)) {
        toWriteLocal.add(r);
      } else {
        toDeleteRemote.add(r.animeId);
      }
    } else if (r.updatedAt.isAfter(l.updatedAt)) {
      toWriteLocal.add(r);
    }
  }

  for (final l in local) {
    final r = remoteById[l.animeId];
    if (r == null) {
      if (isNewSince(l)) {
        toPush.add(l);
      } else {
        toDeleteLocal.add(l.animeId);
      }
    } else if (l.updatedAt.isAfter(r.updatedAt)) {
      toPush.add(l);
    }
  }

  return FavoritesMergePlan(
    toWriteLocal: toWriteLocal,
    toPush: toPush,
    toDeleteLocal: toDeleteLocal,
    toDeleteRemote: toDeleteRemote,
  );
}

/// Coordinator hidup selama sesi + dengar perubahan box favorit.
final favoritesSyncCoordinatorProvider = Provider<FavoritesSyncCoordinator>((
  ref,
) {
  final coord = FavoritesSyncCoordinator(ref);
  final sub = ref
      .watch(favoritesRepositoryProvider)
      .watchAll()
      .skip(1) // emit pertama = snapshot awal, bukan perubahan
      .listen((_) => coord.onFavoritesChanged());
  ref.onDispose(() {
    sub.cancel();
    coord.dispose();
  });
  return coord;
});

/// Helper dari widget (Home initState / setelah login) — pull→merge→push.
Future<void> syncFavorites(WidgetRef ref) =>
    ref.read(favoritesSyncCoordinatorProvider).syncNow();
