import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/history/data/history_entry.dart';
import 'package:vibenime/features/history/data/watch_history_sync_coordinator.dart';

HistoryEntry _entry({
  int animeId = 1,
  String episodeId = 'ep-1-1',
  int position = 100,
  required DateTime watchedAt,
}) {
  return HistoryEntry(
    animeId: animeId,
    episodeId: episodeId,
    episodeNumber: 1,
    positionSeconds: position,
    watchedAt: watchedAt,
  );
}

void main() {
  final t0 = DateTime(2026, 1, 1, 10);
  final t1 = DateTime(2026, 1, 1, 12); // lebih baru

  group('planMerge last-write-wins', () {
    test('remote lebih baru → tulis ke lokal, tidak push', () {
      final local = [_entry(position: 50, watchedAt: t0)];
      final remote = [_entry(position: 200, watchedAt: t1)];

      final plan = planMerge(local: local, remote: remote);

      expect(plan.toWriteLocal, hasLength(1));
      expect(plan.toWriteLocal.first.positionSeconds, 200);
      expect(plan.toPush, isEmpty);
    });

    test('lokal lebih baru → push, tidak tulis lokal', () {
      final local = [_entry(position: 200, watchedAt: t1)];
      final remote = [_entry(position: 50, watchedAt: t0)];

      final plan = planMerge(local: local, remote: remote);

      expect(plan.toPush, hasLength(1));
      expect(plan.toPush.first.positionSeconds, 200);
      expect(plan.toWriteLocal, isEmpty);
    });

    test('hanya ada di remote → tulis ke lokal', () {
      final plan = planMerge(
        local: const [],
        remote: [_entry(watchedAt: t0)],
      );
      expect(plan.toWriteLocal, hasLength(1));
      expect(plan.toPush, isEmpty);
    });

    test('hanya ada di lokal → push', () {
      final plan = planMerge(
        local: [_entry(watchedAt: t0)],
        remote: const [],
      );
      expect(plan.toPush, hasLength(1));
      expect(plan.toWriteLocal, isEmpty);
    });

    test('watchedAt sama → tidak ada aksi (sudah sinkron)', () {
      final plan = planMerge(
        local: [_entry(position: 50, watchedAt: t0)],
        remote: [_entry(position: 50, watchedAt: t0)],
      );
      expect(plan.toWriteLocal, isEmpty);
      expect(plan.toPush, isEmpty);
    });

    test('episode berbeda diperlakukan independen', () {
      final local = [
        _entry(
          episodeId: 'ep-1-1',
          position: 200,
          watchedAt: t1,
        ), // lokal menang
        _entry(
          episodeId: 'ep-1-2',
          position: 10,
          watchedAt: t0,
        ), // remote menang
      ];
      final remote = [
        _entry(episodeId: 'ep-1-1', position: 5, watchedAt: t0),
        _entry(episodeId: 'ep-1-2', position: 300, watchedAt: t1),
      ];

      final plan = planMerge(local: local, remote: remote);

      expect(plan.toPush.map((e) => e.episodeId), ['ep-1-1']);
      expect(plan.toWriteLocal.map((e) => e.episodeId), ['ep-1-2']);
    });
  });
}
