import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/player/data/aniwatch_client.dart';

/// Satu route: predikat atas [Uri] → (status, body JSON). Status bisa 5xx untuk
/// menguji ketahanan (client tak lempar, kandidat berikutnya tetap dicoba).
typedef _Route = (
  bool Function(Uri uri),
  int status,
  Map<String, dynamic> body,
);

/// Fake adapter: route berdasar Uri (path + query), balas JSON canned.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final List<_Route> routes;
  final hits = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits.add(options.uri.toString());
    for (final (match, status, body) in routes) {
      if (match(options.uri)) {
        return ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      '{}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AniwatchClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AniwatchClient(dio);
}

/// Envelope helper `{success, data}`.
Map<String, dynamic> _ok(Map<String, dynamic> data) => {
  'success': true,
  'data': data,
};

void main() {
  setUpAll(
    () => dotenv.testLoad(mergeWith: {'ANIWATCH_API_URL': 'https://a.test'}),
  );

  _Route searchRoute(
    String contains,
    List<Map<String, dynamic>> animes, {
    int status = 200,
  }) => (
    (u) =>
        u.path.endsWith('/search') &&
        (u.queryParameters['q'] ?? '') == contains,
    status,
    _ok({'animes': animes}),
  );

  _Route episodesRoute(String slug, List<int> nums) => (
    (u) => u.path.endsWith('/anime/$slug/episodes'),
    200,
    _ok({
      'episodes': [
        for (final n in nums) {'episodeId': '$slug?ep=$n', 'number': n},
      ],
    }),
  );

  _Route sourcesRoute(Map<String, dynamic> data) =>
      ((u) => u.path.endsWith('/episode/sources'), 200, _ok(data));

  test(
    'happy path: m3u8 + subtitle + intro/outro + headers ke-parse',
    () async {
      final adapter = _FakeAdapter([
        searchRoute('Frieren', [
          {'id': 'other', 'name': 'Some Other Anime'},
          {'id': 'frieren-slug', 'name': 'Frieren'},
        ]),
        episodesRoute('frieren-slug', [1, 2]),
        sourcesRoute({
          'sources': [
            {'url': 'https://cdn/master.m3u8', 'type': 'hls'},
          ],
          'tracks': [
            {
              'file': 'https://cdn/en.vtt',
              'label': 'English',
              'kind': 'captions',
            },
            {'file': 'https://cdn/thumb.vtt', 'kind': 'thumbnails'},
          ],
          'headers': {'Referer': 'https://megacloud.tv/'},
          'intro': {'start': 0, 'end': 85},
          'outro': {'start': 1300, 'end': 1420},
        }),
      ]);

      final r = await _clientWith(
        adapter,
      ).fetch(anilistId: 1, animeTitle: 'Frieren', episodeNumber: 1);
      expect(r, isNotNull);
      expect(r!.sources, hasLength(1));
      expect(r.sources.first.isHls, isTrue);
      // thumbnails di-skip → hanya 1 subtitle.
      expect(r.subtitles, hasLength(1));
      expect(r.subtitles.first.language, 'English');
      expect(r.headers['Referer'], 'https://megacloud.tv/');
      expect(r.introEnd, 85);
      expect(r.outroStart, 1300);
    },
  );

  test(
    'best-match: pilih judul token-overlap terbaik (bukan hasil pertama)',
    () async {
      final adapter = _FakeAdapter([
        searchRoute('Bocchi the Rock', [
          {'id': 'wrong', 'name': 'Rock Lee'},
          {'id': 'right', 'name': 'Bocchi the Rock'},
        ]),
        episodesRoute('right', [1]),
        sourcesRoute({
          'sources': [
            {'url': 'https://cdn/r.m3u8', 'type': 'hls'},
          ],
        }),
      ]);

      final r = await _clientWith(
        adapter,
      ).fetch(anilistId: 2, animeTitle: 'Bocchi the Rock', episodeNumber: 1);
      expect(r, isNotNull);
      // Episodes route hanya cocok untuk slug 'right' → bukti best-match kepilih.
      expect(r!.sources.single.url, contains('r.m3u8'));
    },
  );

  test(
    'kandidat judul yang bikin 500 di-skip, kandidat berikutnya dipakai',
    () async {
      final adapter = _FakeAdapter([
        // Judul penuh (dengan ":") → server 500.
        searchRoute("Frieren: Beyond Journey's End", const [], status: 500),
        // Varian tanpa ":" → valid.
        searchRoute('Frieren', [
          {'id': 'frieren-slug', 'name': 'Frieren'},
        ]),
        episodesRoute('frieren-slug', [1]),
        sourcesRoute({
          'sources': [
            {'url': 'https://cdn/ok.m3u8', 'type': 'hls'},
          ],
        }),
      ]);

      final r = await _clientWith(adapter).fetch(
        anilistId: 3,
        animeTitle: "Frieren: Beyond Journey's End",
        episodeNumber: 1,
      );
      expect(r, isNotNull);
      expect(r!.sources.single.url, contains('ok.m3u8'));
    },
  );

  test('episode tidak ada → null', () async {
    final adapter = _FakeAdapter([
      searchRoute('X', [
        {'id': 'x-slug', 'name': 'X'},
      ]),
      episodesRoute('x-slug', [1, 2]),
    ]);
    final r = await _clientWith(
      adapter,
    ).fetch(anilistId: 4, animeTitle: 'X', episodeNumber: 99);
    expect(r, isNull);
  });

  test('search kosong → null', () async {
    final adapter = _FakeAdapter([searchRoute('Nope', const [])]);
    final r = await _clientWith(
      adapter,
    ).fetch(anilistId: 5, animeTitle: 'Nope', episodeNumber: 1);
    expect(r, isNull);
  });

  test(
    'tak ter-konfigurasi (ANIWATCH_API_URL kosong) → null tanpa request',
    () async {
      dotenv.testLoad(mergeWith: {'ANIWATCH_API_URL': ''});
      final adapter = _FakeAdapter([]);
      final r = await _clientWith(
        adapter,
      ).fetch(anilistId: 6, animeTitle: 'Anything', episodeNumber: 1);
      expect(r, isNull);
      expect(adapter.hits, isEmpty);
      // Restore untuk test lain (urutan tak dijamin, tapi aman).
      dotenv.testLoad(mergeWith: {'ANIWATCH_API_URL': 'https://a.test'});
    },
  );

  test('debugSearchVariants: buang klausa setelah ":" + suffix season', () {
    final v = AniwatchClient.debugSearchVariants(
      "Frieren: Beyond Journey's End",
    );
    expect(v.first, "Frieren: Beyond Journey's End");
    expect(v, contains('Frieren'));
  });
}
