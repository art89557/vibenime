import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/player/data/miruro_client.dart';

/// Fake adapter: route berdasar path, balas JSON canned (tanpa network).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);
  final Map<bool Function(Uri uri), Map<String, dynamic>> routes;
  final hits = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits.add(options.uri.path);
    for (final entry in routes.entries) {
      if (entry.key(options.uri)) {
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

MiruroClient _clientWith(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return MiruroClient(dio);
}

void main() {
  setUpAll(
    () => dotenv.testLoad(mergeWith: {'MIRURO_API_URL': 'https://m.test'}),
  );

  Map<String, dynamic> episodesWith(Map<String, List<int>> providerEps) {
    final providers = <String, dynamic>{};
    providerEps.forEach((name, nums) {
      providers[name] = {
        'episodes': {
          'sub': [
            for (final n in nums)
              {'id': 'watch/$name/1/sub/$name-$n', 'number': n},
          ],
        },
      };
    });
    return {'providers': providers};
  }

  test('HLS dipilih, embed di-skip; subtitle + intro/outro ke-parse', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.endsWith('/episodes/178005'): episodesWith({
        'kiwi': [1, 2],
      }),
      (u) => u.path.contains('/watch/kiwi/1/sub/kiwi-1'): {
        'streams': [
          {'url': 'https://cdn/master.m3u8', 'type': 'hls', 'quality': '1080p'},
          {'url': 'https://kwik.cx/e/abc', 'type': 'embed', 'quality': '1080p'},
        ],
        'subtitles': [
          {
            'file': 'https://cdn/en.vtt',
            'label': 'English',
            'kind': 'captions',
          },
          {'file': 'https://cdn/t.vtt', 'kind': 'thumbnails'},
        ],
        'intro': {'start': 0, 'end': 90},
        'outro': {'start': 1300, 'end': 1420},
      },
    });

    final r = await _clientWith(
      adapter,
    ).fetch(anilistId: 178005, episodeNumber: 1);
    expect(r, isNotNull);
    // embed di-buang → hanya 1 HLS.
    expect(r!.sources, hasLength(1));
    expect(r.sources.first.isHls, isTrue);
    // thumbnails di-skip → 1 subtitle.
    expect(r.subtitles, hasLength(1));
    expect(r.introEnd, 90);
    expect(r.outroStart, 1300);
  });

  test('provider embed-only di-skip, lanjut ke provider HLS', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.endsWith('/episodes/1'): episodesWith({
        'ally': [1], // embed-only → harus dilewati
        'kiwi': [1], // HLS → harus dipakai
      }),
      (u) => u.path.contains('/watch/ally/'): {
        'streams': [
          {'url': 'https://kwik.cx/e/x', 'type': 'embed'},
        ],
      },
      (u) => u.path.contains('/watch/kiwi/'): {
        'streams': [
          {'url': 'https://cdn/k.m3u8', 'type': 'hls', 'quality': '720p'},
        ],
      },
    });

    final r = await _clientWith(adapter).fetch(anilistId: 1, episodeNumber: 1);
    expect(r, isNotNull);
    expect(r!.sources.single.url, contains('.m3u8'));
  });

  test('episode tidak ada → null', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.endsWith('/episodes/1'): episodesWith({
        'kiwi': [1, 2],
      }),
    });
    final r = await _clientWith(adapter).fetch(anilistId: 1, episodeNumber: 99);
    expect(r, isNull);
  });

  test('providers kosong → null', () async {
    final adapter = _FakeAdapter({
      (u) => u.path.endsWith('/episodes/1'): {'providers': {}},
    });
    final r = await _clientWith(adapter).fetch(anilistId: 1, episodeNumber: 1);
    expect(r, isNull);
  });
}
