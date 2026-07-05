import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';

/// Arah pergeseran peringkat sebuah anime di tab Weekly.
enum RankTrend {
  /// Naik dibanding snapshot sebelumnya.
  rising,

  /// Turun dibanding snapshot sebelumnya.
  falling,

  /// Posisi sama.
  steady,

  /// Belum ada di snapshot sebelumnya (baru masuk leaderboard).
  fresh,
}

/// Menyimpan snapshot urutan peringkat **Weekly** ke Hive (box `settings`) lalu
/// membandingkannya untuk menghasilkan indikator tren (panah naik/turun).
///
/// AniList tidak menyimpan riwayat peringkat, jadi tren dihitung lokal:
/// day-over-day. Snapshot hanya ditimpa kalau sudah lebih tua dari [_staleness]
/// supaya buka berkali-kali di hari yang sama tetap membandingkan ke kemarin.
class RankTrendStore {
  RankTrendStore(this._box);

  final Box<dynamic> _box;

  static const _key = 'weekly_rank_snapshot';
  static const _staleness = Duration(days: 1);

  /// Hitung tren tiap anime dari [currentIds] (urut peringkat #1..#N) terhadap
  /// snapshot tersimpan, lalu simpan snapshot baru kalau sudah basi.
  Map<int, RankTrend> computeAndMaybeSave(List<int> currentIds) {
    final raw = _box.get(_key);
    final prevIds = raw is Map
        ? (raw['ids'] as List?)?.map((e) => (e as num).toInt()).toList() ??
              const <int>[]
        : const <int>[];
    final savedAt = raw is Map ? raw['savedAt'] as int? : null;

    final result = <int, RankTrend>{};
    for (var i = 0; i < currentIds.length; i++) {
      final id = currentIds[i];
      final prevIndex = prevIds.indexOf(id);
      if (prevIndex < 0) {
        result[id] = RankTrend.fresh;
      } else if (i < prevIndex) {
        result[id] = RankTrend.rising; // index lebih kecil = peringkat naik
      } else if (i > prevIndex) {
        result[id] = RankTrend.falling;
      } else {
        result[id] = RankTrend.steady;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final stale = savedAt == null || now - savedAt > _staleness.inMilliseconds;
    if (stale && currentIds.isNotEmpty) {
      _box.put(_key, {'ids': currentIds, 'savedAt': now});
    }
    return result;
  }
}

final rankTrendStoreProvider = Provider<RankTrendStore>((ref) {
  return RankTrendStore(Hive.box<dynamic>(HiveBoxes.settings));
});
