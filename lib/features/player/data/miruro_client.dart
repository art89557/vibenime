import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../shared/models/stream_source.dart';

/// Hasil fetch dari Miruro-API untuk satu episode.
class MiruroResult {
  const MiruroResult({
    this.sources = const [],
    this.subtitles = const [],
    this.headers = const {},
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });

  final List<StreamSource> sources;
  final List<SubtitleTrack> subtitles;

  /// Header HTTP yang HARUS dikirim player ke CDN saat ambil m3u8/segment.
  /// Miruro kasih `referer` per-stream (mis. `https://kwik.cx/e/...`) — CDN
  /// (uwucdn/kwik) cek Referer ini; tanpa-nya balas **403**. Diteruskan ke
  /// `StreamPayload.headers` → `BetterPlayerDataSource.headers` → ExoPlayer.
  final Map<String, String> headers;
  final double? introStart;
  final double? introEnd;
  final double? outroStart;
  final double? outroEnd;

  bool get isEmpty => sources.isEmpty;
}

/// Client untuk **Miruro-API** (github.com/walterwhite-69/Miruro-API) — backend
/// Python/FastAPI yang balas **M3U8 langsung** + subtitle + intro/outro,
/// di-key oleh **AniList ID** (tak perlu tebak judul). Sub EN.
///
/// **Alur 2-step** (diverifikasi terhadap backend asli):
/// 1. `GET /episodes/{anilistId}` → `providers.{kiwi|hop|bee|...}.episodes.{sub|dub}[]`.
///    Tiap provider punya episode id sendiri (mis. `watch/kiwi/178005/sub/animepahe-1`).
/// 2. `GET /{id}` → `streams[]` (campur HLS + embed), `subtitles[]`,
///    `intro{start,end}`, `outro{start,end}`. Beberapa provider hanya embed
///    (tak playable) → iterasi provider sampai dapat HLS.
///
/// **Auth:** backend menolak request tanpa `Origin`/`Referer` (atau `x-api-key`).
/// Header dikirim via Dio (lihat [miruroClientProvider]).
class MiruroClient {
  MiruroClient(this._dio);

  final Dio _dio;

  String get _base => Env.miruroApiUrl;

  /// Maks provider di-probe per episode (batasi latency).
  static const _maxProviderProbe = 4;

  /// Provider yang diketahui paling andal (HLS + CDN bagus) → dicoba dulu.
  static const _preferredOrder = ['kiwi', 'bee', 'bonk', 'moo', 'hop'];

  /// Cache providers map mentah per anilistId (hasil step 1).
  final _episodesCache = <int, Map<String, dynamic>>{};

  Future<MiruroResult?> fetch({
    required int anilistId,
    required int episodeNumber,
    bool preferDub = false,
  }) async {
    if (!Env.isMiruroConfigured || anilistId <= 0) return null;
    final category = preferDub ? 'dub' : 'sub';
    try {
      final providers = await _getProviders(anilistId);
      if (providers == null) return null;

      // Kumpulkan (providerKey, episodeId) untuk episode ini, urut preferensi.
      final candidates = _candidateEpisodeIds(
        providers: providers,
        episodeNumber: episodeNumber,
        category: category,
      );

      var probed = 0;
      for (final id in candidates) {
        if (probed >= _maxProviderProbe) break;
        probed++;
        final result = await _fetchSources(id);
        if (result != null && !result.isEmpty) return result;
      }
      return null;
    } catch (e) {
      debugPrint('🎬 [miruro] gagal: $e');
      return null;
    }
  }

  // ─── Step 1: providers map (cached) ─────────────────────────────────────

  Future<Map<String, dynamic>?> _getProviders(int anilistId) async {
    final cached = _episodesCache[anilistId];
    if (cached != null) return cached;
    final res = await _dio.get<Map<String, dynamic>>(
      '$_base/episodes/$anilistId',
      options: _opts,
    );
    final providers = res.data?['providers'] as Map<String, dynamic>?;
    if (providers == null || providers.isEmpty) return null;
    _episodesCache[anilistId] = providers;
    return providers;
  }

  /// Daftar episodeId kandidat (lintas provider) untuk episode ke-N,
  /// urut: provider preferensi dulu, lalu sisanya. Coba kategori diminta
  /// dulu, fallback kategori lain.
  List<String> _candidateEpisodeIds({
    required Map<String, dynamic> providers,
    required int episodeNumber,
    required String category,
  }) {
    final keys = <String>[
      ..._preferredOrder.where(providers.containsKey),
      ...providers.keys.where((k) => !_preferredOrder.contains(k)),
    ];
    final out = <String>[];
    for (final cat in [category, category == 'sub' ? 'dub' : 'sub']) {
      for (final key in keys) {
        final prov = providers[key] as Map<String, dynamic>?;
        final list =
            (prov?['episodes'] as Map<String, dynamic>?)?[cat] as List?;
        if (list == null) continue;
        for (final raw in list.cast<Map<String, dynamic>>()) {
          if ((raw['number'] as num?)?.toInt() == episodeNumber) {
            final id = raw['id'] as String?;
            if (id != null && id.isNotEmpty) out.add(id);
          }
        }
      }
      if (out.isNotEmpty) break; // kategori utama dapat → tak perlu fallback
    }
    return out;
  }

  // ─── Step 2: fetch sources (HLS-only) + subtitle + intro/outro ──────────

  Future<MiruroResult?> _fetchSources(String episodeId) async {
    final path = episodeId.startsWith('/') ? episodeId : '/$episodeId';
    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.get<Map<String, dynamic>>('$_base$path', options: _opts);
    } catch (_) {
      return null; // provider ini gagal → caller coba berikutnya
    }
    final data = res.data;
    if (data == null) return null;

    final streamsRaw = data['streams'] as List?;
    if (streamsRaw == null || streamsRaw.isEmpty) return null;

    // HANYA terima HLS/direct — buang `type:"embed"` (kwik.cx dll) yang
    // tak bisa diputar better_player.
    final sources = <StreamSource>[];
    String? streamReferer;
    for (final raw in streamsRaw.cast<Map<String, dynamic>>()) {
      final url = raw['url'] as String?;
      if (url == null || url.isEmpty) continue;
      final type = (raw['type'] as String?)?.toLowerCase();
      final isHls = type == 'hls' || url.contains('.m3u8');
      final isMp4 = type == 'mp4' || url.contains('.mp4');
      if (!isHls && !isMp4) continue; // skip embed/iframe
      // Referer per-stream (mis. `https://kwik.cx/e/...`) WAJIB diteruskan ke
      // CDN, kalau tidak balas 403. Ambil dari stream playable pertama (=
      // primarySource yang dipilih player).
      streamReferer ??= raw['referer'] as String?;
      sources.add(
        StreamSource(
          url: url,
          type: isHls ? 'hls' : 'mp4',
          quality: raw['quality'] as String?,
        ),
      );
    }
    if (sources.isEmpty) return null;

    // Build header CDN dari referer stream. Tanpa Referer → uwucdn/kwik 403.
    final headers = <String, String>{};
    if (streamReferer != null && streamReferer.isNotEmpty) {
      headers['Referer'] = streamReferer;
      final u = Uri.tryParse(streamReferer);
      if (u != null && u.hasScheme) {
        headers['Origin'] = '${u.scheme}://${u.host}';
      }
      headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    }

    final subtitles = <SubtitleTrack>[];
    final subsRaw = data['subtitles'] as List?;
    if (subsRaw != null) {
      for (final raw in subsRaw.cast<Map<String, dynamic>>()) {
        final kind = (raw['kind'] as String?)?.toLowerCase();
        if (kind == 'thumbnails') continue;
        final file = raw['file'] as String?;
        if (file == null || file.isEmpty) continue;
        subtitles.add(
          SubtitleTrack(url: file, language: raw['label'] as String?),
        );
      }
    }

    final intro = data['intro'] as Map<String, dynamic>?;
    final outro = data['outro'] as Map<String, dynamic>?;

    return MiruroResult(
      sources: sources,
      subtitles: subtitles,
      headers: headers,
      introStart: (intro?['start'] as num?)?.toDouble(),
      introEnd: (intro?['end'] as num?)?.toDouble(),
      outroStart: (outro?['start'] as num?)?.toDouble(),
      outroEnd: (outro?['end'] as num?)?.toDouble(),
    );
  }

  Options get _opts => Options(
    sendTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 20),
    validateStatus: (s) => s != null && s < 500,
  );

  void resetCache() => _episodesCache.clear();
}

final miruroClientProvider = Provider<MiruroClient>((ref) {
  final dio = Dio(
    BaseOptions(
      headers: {
        // Backend Miruro menolak request tanpa Origin/Referer (atau x-api-key).
        // ALLOWED_ORIGINS kosong di server → Referer apa pun diterima.
        'Referer': 'https://www.miruro.tv/',
        'Origin': 'https://www.miruro.tv',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        // Kalau deploy di-lock dengan API_KEY, kirim x-api-key.
        if (Env.miruroApiKey.isNotEmpty) 'x-api-key': Env.miruroApiKey,
      },
    ),
  );
  return MiruroClient(dio);
});
