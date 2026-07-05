import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/favorites/data/favorite_entry.dart';
import 'package:vibenime/features/favorites/data/favorites_sync_coordinator.dart';

FavoriteEntry _fav(
  int id, {
  required DateTime updatedAt,
  WatchStatus status = WatchStatus.planning,
}) {
  return FavoriteEntry(
    animeId: id,
    title: 'A$id',
    coverImage: '',
    addedAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt,
    status: status,
  );
}

void main() {
  final t0 = DateTime(2026, 1, 1, 10);
  final tSync = DateTime(2026, 1, 2, 12); // last sync
  final t1 = DateTime(2026, 1, 3, 9); // setelah sync

  group('planMergeFavorites', () {
    test('first sync (lastSyncAt null) → union, tanpa hapus', () {
      final plan = planMergeFavorites(
        local: [_fav(1, updatedAt: t0)],
        remote: [_fav(2, updatedAt: t0)],
        lastSyncAt: null,
      );
      expect(plan.toPush.map((e) => e.animeId), [1]);
      expect(plan.toWriteLocal.map((e) => e.animeId), [2]);
      expect(plan.toDeleteLocal, isEmpty);
      expect(plan.toDeleteRemote, isEmpty);
    });

    test('dua sisi: remote lebih baru → tulis lokal (status ikut remote)', () {
      final plan = planMergeFavorites(
        local: [_fav(1, updatedAt: t0, status: WatchStatus.planning)],
        remote: [_fav(1, updatedAt: t1, status: WatchStatus.completed)],
        lastSyncAt: tSync,
      );
      expect(plan.toWriteLocal.single.status, WatchStatus.completed);
      expect(plan.toPush, isEmpty);
    });

    test('dua sisi: lokal lebih baru → push', () {
      final plan = planMergeFavorites(
        local: [_fav(1, updatedAt: t1, status: WatchStatus.watching)],
        remote: [_fav(1, updatedAt: t0)],
        lastSyncAt: tSync,
      );
      expect(plan.toPush.single.status, WatchStatus.watching);
      expect(plan.toWriteLocal, isEmpty);
    });

    test(
      'hanya remote & baru setelah sync → tulis lokal (dari device lain)',
      () {
        final plan = planMergeFavorites(
          local: const [],
          remote: [_fav(5, updatedAt: t1)],
          lastSyncAt: tSync,
        );
        expect(plan.toWriteLocal.map((e) => e.animeId), [5]);
        expect(plan.toDeleteRemote, isEmpty);
      },
    );

    test(
      'hanya remote & LAMA (<= lastSync) → dihapus lokal → hapus remote',
      () {
        final plan = planMergeFavorites(
          local: const [],
          remote: [_fav(5, updatedAt: t0)],
          lastSyncAt: tSync,
        );
        expect(plan.toDeleteRemote, [5]);
        expect(plan.toWriteLocal, isEmpty);
      },
    );

    test('hanya lokal & baru setelah sync → push', () {
      final plan = planMergeFavorites(
        local: [_fav(7, updatedAt: t1)],
        remote: const [],
        lastSyncAt: tSync,
      );
      expect(plan.toPush.map((e) => e.animeId), [7]);
      expect(plan.toDeleteLocal, isEmpty);
    });

    test(
      'hanya lokal & LAMA (<= lastSync) → dihapus device lain → hapus lokal',
      () {
        final plan = planMergeFavorites(
          local: [_fav(7, updatedAt: t0)],
          remote: const [],
          lastSyncAt: tSync,
        );
        expect(plan.toDeleteLocal, [7]);
        expect(plan.toPush, isEmpty);
      },
    );

    test('updatedAt seri di dua sisi → no-op', () {
      final plan = planMergeFavorites(
        local: [_fav(1, updatedAt: t0)],
        remote: [_fav(1, updatedAt: t0)],
        lastSyncAt: tSync,
      );
      expect(plan.toWriteLocal, isEmpty);
      expect(plan.toPush, isEmpty);
      expect(plan.toDeleteLocal, isEmpty);
      expect(plan.toDeleteRemote, isEmpty);
    });
  });
}
