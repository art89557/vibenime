import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/discover/data/for_you_repository.dart';
import 'package:vibenime/features/favorites/data/favorite_entry.dart';
import 'package:vibenime/features/history/data/history_entry.dart';

FavoriteEntry _fav(int id, WatchStatus status) => FavoriteEntry(
  animeId: id,
  title: 'A$id',
  coverImage: '',
  addedAt: DateTime(2026, 1, 1),
  status: status,
);

HistoryEntry _hist(int id) => HistoryEntry(
  animeId: id,
  episodeId: 'ep-$id-1',
  episodeNumber: 1,
  positionSeconds: 100,
  watchedAt: DateTime(2026, 1, 1),
);

void main() {
  group('weightSeeds', () {
    test('favorit watching/completed = 3, planning = 2, history = 1', () {
      final w = weightSeeds(
        favorites: [
          _fav(1, WatchStatus.completed),
          _fav(2, WatchStatus.watching),
          _fav(3, WatchStatus.planning),
        ],
        history: [_hist(4)],
      );
      expect(w[1], 3);
      expect(w[2], 3);
      expect(w[3], 2);
      expect(w[4], 1);
    });

    test('bobot diakumulasi kalau anime ada di favorit + history', () {
      final w = weightSeeds(
        favorites: [_fav(1, WatchStatus.planning)], // 2
        history: [_hist(1)], // +1
      );
      expect(w[1], 3);
    });

    test('kosong kalau tak ada seed', () {
      expect(weightSeeds(favorites: const [], history: const []), isEmpty);
    });
  });

  group('rankGenres', () {
    test('genre dari seed berbobot tinggi menang', () {
      final seedGenres = {
        1: ['Action', 'Romance'],
        2: ['Action', 'Comedy'],
        3: ['Slice of Life'],
      };
      final weights = {1: 3, 2: 3, 3: 1};
      // Action = 3+3 = 6, Romance = 3, Comedy = 3, Slice = 1.
      final top = rankGenres(seedGenres, weights, take: 2);
      expect(top.first, 'Action');
      expect(top, hasLength(2));
    });

    test('take membatasi jumlah genre', () {
      final seedGenres = {
        1: ['A', 'B', 'C', 'D'],
      };
      final top = rankGenres(seedGenres, {1: 1}, take: 3);
      expect(top, hasLength(3));
    });

    test('bobot default 1 kalau id tak ada di weights', () {
      final top = rankGenres(
        {
          9: ['Horror'],
        },
        const {},
        take: 3,
      );
      expect(top, ['Horror']);
    });

    test('kosong kalau tak ada genre', () {
      expect(rankGenres(const {}, const {}), isEmpty);
    });
  });
}
