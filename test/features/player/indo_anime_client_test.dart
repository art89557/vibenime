import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/player/data/indo_anime_client.dart';

/// Fake adapter: route berdasar path + query, kembalikan JSON canned —
/// tanpa network. Menguji alur lengkap wajik-anime-api (search → anime →
/// episode → server).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  /// Map: predicate(uri) → json body string.
  final Map<bool Function(Uri uri), Map<String, dynamic>> routes;

  int searchCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    if (uri.path.contains('/search')) searchCalls++;
    for (final entry in routes.entries) {
      if (entry.key(uri)) {
        return ResponseBody.fromString(
          jsonEncode(entry.value),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
    }
    return ResponseBody.fromString(
      '{"data":null}',
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

IndoAnimeClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return IndoAnimeClient(dio);
}

void main() {
  // `Env.animeApiUrl` baca dotenv → load kosong supaya tidak NotInitializedError
  // (base URL jatuh ke public demo, tapi semua request di-intercept fake adapter).
  setUpAll(() => dotenv.testLoad(mergeWith: {}));

  final searchOk = {
    'data': {
      'animeList': [
        {'animeId': 'naruto-sub-indo', 'title': 'Naruto'},
      ],
    },
  };
  final animeOk = {
    'data': {
      'episodeList': [
        {
          'title': 'Naruto Episode 2 Subtitle Indonesia',
          'episodeId': 'naruto-2',
        },
        {
          'title': 'Naruto Episode 1 Subtitle Indonesia',
          'episodeId': 'naruto-1',
        },
      ],
    },
  };

  test('direct .mp4 → masuk sources, episode benar', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.contains('/search'): searchOk,
      (u) => u.path.contains('/anime/naruto-sub-indo'): animeOk,
      (u) => u.path.contains('/episode/naruto-1'): {
        'data': {
          'defaultStreamingUrl': 'https://embed.host/iframe/xyz',
          'server': {
            'qualityList': [
              {
                'serverList': [
                  {'title': '720p', 'serverId': 'srv-direct'},
                ],
              },
            ],
          },
        },
      },
      (u) => u.path.contains('/server/srv-direct'): {
        'data': {'url': 'https://cdn.host/naruto-1-720p.mp4'},
      },
    });

    final result = await _clientWith(
      adapter,
    ).fetchSources(anilistId: 20, animeTitle: 'Naruto', episodeNumber: 1);

    expect(result, isNotNull);
    expect(result!.sources, hasLength(1));
    expect(result.sources.first.url, contains('.mp4'));
    expect(result.embedUrl, isNull);
  });

  test('hanya embed → pakai defaultStreamingUrl', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.contains('/search'): searchOk,
      (u) => u.path.contains('/anime/naruto-sub-indo'): animeOk,
      (u) => u.path.contains('/episode/naruto-2'): {
        'data': {
          'defaultStreamingUrl': 'https://embed.host/iframe/ep2',
          'server': {
            'qualityList': [
              {
                'serverList': [
                  {'title': 'Desustream', 'serverId': 'srv-embed'},
                ],
              },
            ],
          },
        },
      },
      (u) => u.path.contains('/server/srv-embed'): {
        'data': {'url': 'https://embed.host/player/ep2'}, // bukan mp4/m3u8
      },
    });

    final result = await _clientWith(
      adapter,
    ).fetchSources(anilistId: 20, animeTitle: 'Naruto', episodeNumber: 2);

    expect(result, isNotNull);
    expect(result!.sources, isEmpty);
    expect(result.embedUrl, 'https://embed.host/iframe/ep2');
    expect(result.isEmpty, isFalse);
  });

  test('anime tidak ketemu → null', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.contains('/search'): {
        'data': {'animeList': []},
      },
    });
    final result = await _clientWith(
      adapter,
    ).fetchSources(anilistId: 99, animeTitle: 'Tidak Ada', episodeNumber: 1);
    expect(result, isNull);
  });

  test('judul kosong → null tanpa hit network', () async {
    final adapter = _FakeAdapter({});
    final result = await _clientWith(
      adapter,
    ).fetchSources(anilistId: 1, animeTitle: '   ', episodeNumber: 1);
    expect(result, isNull);
    expect(adapter.searchCalls, 0);
  });

  test('cache: episode kedua dari anime sama tidak search ulang', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.contains('/search'): searchOk,
      (u) => u.path.contains('/anime/naruto-sub-indo'): animeOk,
      (u) => u.path.contains('/episode/'): {
        'data': {
          'defaultStreamingUrl': 'https://embed.host/iframe/x',
          'server': {'qualityList': []},
        },
      },
    });
    final client = _clientWith(adapter);
    await client.fetchSources(
      anilistId: 20,
      animeTitle: 'Naruto',
      episodeNumber: 1,
    );
    await client.fetchSources(
      anilistId: 20,
      animeTitle: 'Naruto',
      episodeNumber: 2,
    );
    // animeId di-cache → search hanya 1x walau 2 episode.
    expect(adapter.searchCalls, 1);
  });

  // ─── Sanka Vollerei shape ────────────────────────────────────────────────
  test(
    'shape Sanka: title int + server.qualities, match via episodeId',
    () async {
      final adapter = _FakeAdapter({
        (u) => u.path.contains('/search'): {
          'data': {
            'animeList': [
              {'animeId': 'naruto-kecil', 'title': 'Naruto Kecil'},
            ],
          },
        },
        (u) => u.path.contains('/anime/naruto-kecil'): {
          'data': {
            'episodeList': [
              {'title': 2, 'episodeId': 'naruto-kecil-episode-2'},
              {'title': 1, 'episodeId': 'naruto-kecil-episode-1'},
            ],
          },
        },
        // Hanya episode-1 yang dirutekan → sukses = episode benar via episodeId.
        (u) => u.path.contains('/episode/naruto-kecil-episode-1'): {
          'data': {
            'defaultStreamingUrl': 'https://embed.host/x',
            'server': {
              'qualities': [
                {
                  'serverList': [
                    {'title': '720p', 'serverId': 'srv-mp4'},
                  ],
                },
              ],
            },
          },
        },
        (u) => u.path.contains('/server/srv-mp4'): {
          'data': {'url': 'https://cdn.host/naruto-kecil-1-720p.mp4'},
        },
      });

      final result = await _clientWith(
        adapter,
      ).fetchSources(anilistId: 20, animeTitle: 'Naruto', episodeNumber: 1);

      expect(result, isNotNull);
      expect(result!.sources, hasLength(1));
      expect(result.sources.first.url, contains('.mp4'));
    },
  );

  // ─── Multi-judul fallback ────────────────────────────────────────────────
  test('altTitles menyelamatkan saat judul utama 0-hasil', () async {
    final adapter = _FakeAdapter({
      (u) =>
          u.path.contains('/search') && u.queryParameters['q'] == 'English': {
        'data': {'animeList': []},
      },
      (u) => u.path.contains('/search') && u.queryParameters['q'] == 'Romaji': {
        'data': {
          'animeList': [
            {'animeId': 'romaji-id', 'title': 'Romaji'},
          ],
        },
      },
      (u) => u.path.contains('/anime/romaji-id'): {
        'data': {
          'episodeList': [
            {'title': 'Romaji Episode 1', 'episodeId': 'romaji-ep-1'},
          ],
        },
      },
      (u) => u.path.contains('/episode/romaji-ep-1'): {
        'data': {
          'defaultStreamingUrl': 'https://embed.host/romaji-1',
          'server': {'qualities': []},
        },
      },
    });

    final result = await _clientWith(adapter).fetchSources(
      anilistId: 7,
      animeTitle: 'English',
      altTitles: ['Romaji'],
      episodeNumber: 1,
    );

    expect(result, isNotNull);
    expect(result!.embedUrl, 'https://embed.host/romaji-1');
  });

  // ─── Best-match (bukan asal .first) ──────────────────────────────────────
  test(
    'pilih match terbaik: "Naruto" menang atas "Naruto Shippuden ..."',
    () async {
      final adapter = _FakeAdapter({
        (u) => u.path.contains('/search'): {
          'data': {
            'animeList': [
              {'animeId': 'wrong', 'title': 'Naruto Shippuden the Movie'},
              {'animeId': 'right', 'title': 'Naruto'},
            ],
          },
        },
        // Hanya anime 'right' dirutekan → sukses = best-match memilih 'right'.
        (u) => u.path.contains('/anime/right'): {
          'data': {
            'episodeList': [
              {'title': 'Naruto Episode 1', 'episodeId': 'right-1'},
            ],
          },
        },
        (u) => u.path.contains('/episode/right-1'): {
          'data': {
            'defaultStreamingUrl': 'https://embed.host/right-1',
            'server': {'qualities': []},
          },
        },
      });

      final result = await _clientWith(
        adapter,
      ).fetchSources(anilistId: 20, animeTitle: 'Naruto', episodeNumber: 1);

      expect(result, isNotNull);
      expect(result!.embedUrl, 'https://embed.host/right-1');
    },
  );

  // ─── _searchVariants (pure) ──────────────────────────────────────────────
  test('searchVariants: strip ":" clause + season + tahun', () {
    final v1 = IndoAnimeClient.debugSearchVariants(
      'Attack on Titan: The Final Season',
    );
    expect(v1, contains('Attack on Titan: The Final Season'));
    expect(v1, contains('Attack on Titan'));

    final v2 = IndoAnimeClient.debugSearchVariants('Naruto (2002)');
    expect(v2.any((s) => s.trim() == 'Naruto'), isTrue);

    final v3 = IndoAnimeClient.debugSearchVariants('Bleach Season 2');
    expect(v3.any((s) => s.trim() == 'Bleach'), isTrue);

    expect(IndoAnimeClient.debugSearchVariants('   '), isEmpty);
  });

  // ─── fetchDownloadOptions (downloadUrl → Pixeldrain + browser fallback) ──
  test(
    'fetchDownloadOptions: Pixeldrain direct + host lain sbg browser, urut',
    () async {
      final adapter = _FakeAdapter({
        (u) => u.path.contains('/search'): searchOk,
        (u) => u.path.contains('/anime/naruto-sub-indo'): animeOk,
        (u) => u.path.contains('/episode/naruto-1'): {
          'data': {
            'downloadUrl': {
              'formats': [
                {
                  'title': 'MP4',
                  'qualities': [
                    {
                      'title': '480p',
                      'urls': [
                        {
                          'title': 'Pixeldrain',
                          'url': 'https://pixeldrain.com/u/BBB480',
                        },
                      ],
                    },
                    {
                      'title': '720p ',
                      'urls': [
                        {
                          'title': 'Krakenfile',
                          'url': 'https://krakenfiles.com/view/x',
                        },
                        {
                          'title': 'Pixeldrain',
                          'url': 'https://pixeldrain.com/u/AAA720',
                        },
                      ],
                    },
                    {
                      'title': '360p',
                      'urls': [
                        {
                          'title': 'Filedon',
                          'url': 'https://filedon.co/view/x',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          },
        },
      });

      final opts = await _clientWith(adapter).fetchDownloadOptions(
        anilistId: 20,
        animeTitle: 'Naruto',
        episodeNumber: 1,
        source: 'samehadaku',
      );

      // Semua kualitas muncul, urut desc (720→480→360).
      // 720p & 480p punya Pixeldrain → direct. 360p (Filedon) → browser.
      expect(opts, hasLength(3));
      expect(opts.first.quality, '720p');
      expect(opts.first.url, 'https://pixeldrain.com/api/file/AAA720?download');
      expect(opts.first.host, 'Pixeldrain');
      expect(opts.first.direct, isTrue);
      expect(opts[1].quality, '480p');
      expect(opts[1].url, 'https://pixeldrain.com/api/file/BBB480?download');
      expect(opts[1].direct, isTrue);
      expect(opts[2].quality, '360p');
      expect(opts[2].host, 'Filedon');
      expect(opts[2].url, 'https://filedon.co/view/x');
      expect(opts[2].direct, isFalse);
    },
  );
}
