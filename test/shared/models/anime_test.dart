import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/shared/models/anime.dart';

/// Verifikasi parsing JSON AniList → domain `Anime` model.
///
/// Critical karena JSON AniList kompleks (nested title{}, coverImage{},
/// trailer{} optional, studios.nodes[]) — gampang missed null-check.
void main() {
  group('Anime.fromAniListMedia', () {
    test('parse minimum fields wajib (id, title.romaji, coverImage)', () {
      final anime = Anime.fromAniListMedia({
        'id': 4082,
        'title': {'romaji': 'Astro Boy'},
        'coverImage': {'large': 'https://anilist.co/cover/4082.jpg'},
      });
      expect(anime.id, 4082);
      expect(anime.title, 'Astro Boy');
      expect(anime.coverImage, 'https://anilist.co/cover/4082.jpg');
      expect(anime.englishTitle, isNull);
    });

    test('prefer english title kalau ada', () {
      final anime = Anime.fromAniListMedia({
        'id': 1,
        'title': {
          'english': 'Spy x Family',
          'romaji': 'Spy x Family',
          'native': 'スパイファミリー',
        },
        'coverImage': {'large': 'https://x.com/c.jpg'},
      });
      expect(anime.title, 'Spy x Family');
      expect(anime.englishTitle, 'Spy x Family');
      expect(anime.nativeTitle, 'スパイファミリー');
    });

    test('parse trailer hanya kalau site == "youtube"', () {
      final withTrailer = Anime.fromAniListMedia({
        'id': 1,
        'title': {'romaji': 'X'},
        'coverImage': {'large': 'x'},
        'trailer': {'id': 'abc123', 'site': 'youtube'},
      });
      expect(withTrailer.trailerYoutubeId, 'abc123');

      final wrongSite = Anime.fromAniListMedia({
        'id': 1,
        'title': {'romaji': 'X'},
        'coverImage': {'large': 'x'},
        'trailer': {'id': 'xyz', 'site': 'dailymotion'},
      });
      expect(wrongSite.trailerYoutubeId, isNull);
    });

    test('parse studios.nodes[0].name → studio', () {
      final anime = Anime.fromAniListMedia({
        'id': 1,
        'title': {'romaji': 'X'},
        'coverImage': {'large': 'x'},
        'studios': {
          'nodes': [
            {'name': 'CloverWorks'},
          ],
        },
      });
      expect(anime.studio, 'CloverWorks');
    });

    test('handle missing optional fields gracefully', () {
      final anime = Anime.fromAniListMedia({
        'id': 1,
        'title': {'romaji': 'X'},
        'coverImage': <String, dynamic>{},
      });
      expect(anime.coverImage, '');
      expect(anime.episodes, isNull);
      expect(anime.averageScore, isNull);
      expect(anime.genres, isEmpty);
      expect(anime.relations, isEmpty);
    });

    test('isReleasing true hanya kalau status == RELEASING', () {
      final airing = Anime.fromAniListMedia({
        'id': 1,
        'title': {'romaji': 'X'},
        'coverImage': {'large': 'x'},
        'status': 'RELEASING',
      });
      expect(airing.isReleasing, isTrue);

      final finished = Anime.fromAniListMedia({
        'id': 1,
        'title': {'romaji': 'X'},
        'coverImage': {'large': 'x'},
        'status': 'FINISHED',
      });
      expect(finished.isReleasing, isFalse);
    });
  });
}
