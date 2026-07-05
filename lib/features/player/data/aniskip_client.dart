import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timestamp intro (OP) & outro (ED) untuk satu episode, dari AniSkip.
/// Detik (double). Null kalau tidak ada datanya.
class SkipTimes {
  const SkipTimes({this.opStart, this.opEnd, this.edStart, this.edEnd});

  final double? opStart;
  final double? opEnd;
  final double? edStart;
  final double? edEnd;

  bool get hasOp => opStart != null && opEnd != null;
  bool get hasEd => edStart != null && edEnd != null;
  bool get isEmpty => !hasOp && !hasEd;

  static const empty = SkipTimes();
}

/// Client untuk **AniSkip API** (api.aniskip.com) — timestamp OP/ED crowd-sourced.
///
/// Butuh **MAL id** (bukan AniList id) + nomor episode + perkiraan durasi.
/// Banyak anime tidak punya data → return [SkipTimes.empty] (jangan blocking).
///
/// Endpoint:
/// `GET /v2/skip-times/{malId}/{ep}?types=op&types=ed&episodeLength={detik}`
/// Response: `{ found, results:[{ interval:{startTime,endTime}, skipType:'op'|'ed' }] }`
class AniSkipClient {
  AniSkipClient(this._dio);

  final Dio _dio;

  static const _base = 'https://api.aniskip.com/v2';

  Future<SkipTimes> fetch({
    required int malId,
    required int episodeNumber,
    required int episodeLengthSeconds,
  }) async {
    if (malId <= 0 || episodeNumber <= 0) return SkipTimes.empty;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/skip-times/$malId/$episodeNumber',
        queryParameters: {
          'types': ['op', 'ed'],
          'episodeLength': episodeLengthSeconds > 0 ? episodeLengthSeconds : 0,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 8),
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final data = res.data;
      if (data == null || data['found'] != true) return SkipTimes.empty;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return SkipTimes.empty;

      double? opStart, opEnd, edStart, edEnd;
      for (final raw in results.cast<Map<String, dynamic>>()) {
        final type = raw['skipType'] as String?;
        final interval = raw['interval'] as Map<String, dynamic>?;
        if (interval == null) continue;
        final start = (interval['startTime'] as num?)?.toDouble();
        final end = (interval['endTime'] as num?)?.toDouble();
        if (start == null || end == null) continue;
        if (type == 'op') {
          opStart = start;
          opEnd = end;
        } else if (type == 'ed') {
          edStart = start;
          edEnd = end;
        }
      }
      return SkipTimes(
        opStart: opStart,
        opEnd: opEnd,
        edStart: edStart,
        edEnd: edEnd,
      );
    } catch (e) {
      debugPrint('⏭️ [aniskip] gagal: $e');
      return SkipTimes.empty;
    }
  }
}

final aniSkipClientProvider = Provider<AniSkipClient>((ref) {
  return AniSkipClient(Dio());
});

/// Argumen untuk [skipTimesProvider].
typedef SkipArgs = ({int malId, int episodeNumber, int episodeLengthSeconds});

/// Fetch SkipTimes untuk satu episode (cached per argumen).
final skipTimesProvider = FutureProvider.family
    .autoDispose<SkipTimes, SkipArgs>((ref, args) async {
      return ref
          .watch(aniSkipClientProvider)
          .fetch(
            malId: args.malId,
            episodeNumber: args.episodeNumber,
            episodeLengthSeconds: args.episodeLengthSeconds,
          );
    });
