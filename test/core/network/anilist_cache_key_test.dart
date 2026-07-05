import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/core/network/anilist_client.dart';

void main() {
  group('AniListClient.cacheKey', () {
    test('urutan variable tidak berpengaruh (stabil)', () {
      final a = AniListClient.cacheKey('QUERY', {'page': 1, 'perPage': 20});
      final b = AniListClient.cacheKey('QUERY', {'perPage': 20, 'page': 1});
      expect(a, b);
    });

    test('variable berbeda → key berbeda', () {
      final a = AniListClient.cacheKey('QUERY', {'page': 1});
      final b = AniListClient.cacheKey('QUERY', {'page': 2});
      expect(a, isNot(b));
    });

    test('document berbeda → key berbeda', () {
      final a = AniListClient.cacheKey('QUERY_A', {'page': 1});
      final b = AniListClient.cacheKey('QUERY_B', {'page': 1});
      expect(a, isNot(b));
    });

    test('tanpa variable → key konsisten', () {
      expect(
        AniListClient.cacheKey('Q', const {}),
        AniListClient.cacheKey('Q', const {}),
      );
    });
  });
}
