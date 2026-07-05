import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/shared/models/recommended_anime.dart';

void main() {
  group('RecommendedAnime.fromAniListNodes', () {
    test('parse node valid + prefer english title', () {
      final out = RecommendedAnime.fromAniListNodes([
        {
          'mediaRecommendation': {
            'id': 5,
            'title': {'romaji': 'Naruto', 'english': 'NARUTO'},
            'coverImage': {'medium': 'http://x/cover.jpg'},
            'averageScore': 82,
          },
        },
      ]);
      expect(out, hasLength(1));
      expect(out.first.id, 5);
      expect(out.first.title, 'NARUTO');
      expect(out.first.coverImage, 'http://x/cover.jpg');
      expect(out.first.averageScore, 82);
    });

    test('skip node tanpa mediaRecommendation / tanpa id', () {
      final out = RecommendedAnime.fromAniListNodes([
        {'mediaRecommendation': null},
        {
          'mediaRecommendation': {'title': {}},
        }, // tak ada id
        {
          'mediaRecommendation': {
            'id': 9,
            'title': {'romaji': 'Bleach'},
            'coverImage': {},
          },
        },
      ]);
      expect(out, hasLength(1));
      expect(out.first.id, 9);
      expect(out.first.title, 'Bleach');
      expect(out.first.coverImage, '');
      expect(out.first.averageScore, isNull);
    });

    test('dedupe by id', () {
      final node = {
        'mediaRecommendation': {
          'id': 1,
          'title': {'romaji': 'A'},
          'coverImage': {},
        },
      };
      final out = RecommendedAnime.fromAniListNodes([node, node]);
      expect(out, hasLength(1));
    });

    test('list kosong → kosong', () {
      expect(RecommendedAnime.fromAniListNodes(const []), isEmpty);
    });
  });
}
