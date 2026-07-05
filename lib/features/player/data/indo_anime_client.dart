import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../shared/models/stream_source.dart';
import '../../downloads/data/download_option.dart';

/// Hasil fetch dari wajik-anime-api — direct sources ATAU embed url.
class IndoFetchResult {
  const IndoFetchResult({
    this.sources = const [],
    this.embedUrl,
    this.subtitles = const [],
    this.headers = const {},
  });

  /// Direct playable URL (`.mp4`/`.m3u8`) — diputar `better_player`.
  final List<StreamSource> sources;

  /// URL embed iframe (Doodstream/desustream/dll) — diputar via `WebView`.
  /// Diisi kalau server hanya kasih embed, bukan direct.
  final String? embedUrl;

  final List<SubtitleTrack> subtitles;

  /// Header playback (Referer) untuk hindari 403 dari host.
  final Map<String, String> headers;

  bool get isEmpty =>
      sources.isEmpty && (embedUrl == null || embedUrl!.isEmpty);
}

/// Client untuk **wajik-anime-api** (github.com/wajik45/wajik-anime-api) —
/// scrape situs anime sub Indonesia (Otakudesu/Samehadaku/Kuramanime).
/// Pengganti Consumet yang sudah tidak reliable.
///
/// **Alur 4-step** (situs pakai slug sendiri, BUKAN AniList ID):
/// 1. `GET /{source}/search?q={title}` → `data.animeList[0].animeId`
/// 2. `GET /{source}/anime/{animeId}` → `data.episodeList[]`, cari episodeId
///    untuk nomor episode (parse dari judul; otakudesu urut terbaru dulu)
/// 3. `GET /{source}/episode/{episodeId}` → `data.defaultStreamingUrl` (embed)
///    + `data.server.qualityList[].serverList[].serverId`
/// 4. `GET /{source}/server/{serverId}` → `data.url`. Kalau `.mp4`/`.m3u8`
///    → direct source; kalau embed → dipakai sebagai embedUrl.
///
/// Hasil step 1 & 2 di-cache in-memory per session.
class IndoAnimeClient {
  IndoAnimeClient(this._dio);

  final Dio _dio;

  /// Default base (dipakai kalau `ANIME_API_URL` kosong) — **Sanka Vollerei**,
  /// API hosted gratis (tanpa self-host) yang dukung Samehadaku + Otakudesu +
  /// 10 sumber lain. Shape response kompatibel dengan client ini
  /// (search→anime→episode→server). Base sudah termasuk `/anime` → path tetap
  /// `/{source}/...`. Override via `ANIME_API_URL` (mis. self-host wajik) tetap
  /// didukung kalau Sanka down/rate-limit.
  static const _publicDemo = 'https://www.sankavollerei.web.id/anime';

  /// Maks server di-resolve per episode saat cari direct link (batasi latency).
  static const _maxServerProbe = 4;

  /// Cache: `{anilistId}:{episodeNumber}` → episodeId.
  final _episodeIdCache = <String, String>{};

  /// Cache: `{source}:{judul-ternormalisasi}` → animeId.
  final _animeIdCache = <String, String>{};

  String get _base => Env.isAnimeApiConfigured ? Env.animeApiUrl : _publicDemo;

  /// Fetch streaming untuk [animeTitle] episode [episodeNumber] dari [source].
  /// [source] = `samehadaku` / `otakudesu`. [altTitles] = judul alternatif
  /// (romaji/native/dll) yang dicoba kalau judul utama tak ketemu — naikkan
  /// match-rate tanpa input manual. Return `null` kalau semua gagal.
  Future<IndoFetchResult?> fetchSources({
    required int anilistId,
    required String animeTitle,
    required int episodeNumber,
    String source = 'otakudesu',
    List<String> altTitles = const [],
  }) async {
    final candidates = _titleCandidates(animeTitle, altTitles);
    if (candidates.isEmpty) return null;

    try {
      final episodeId = await _resolveEpisodeId(
        source: source,
        anilistId: anilistId,
        candidates: candidates,
        episodeNumber: episodeNumber,
      );
      if (episodeId == null) return null;

      return await _fetchEpisode(source: source, episodeId: episodeId);
    } catch (e) {
      debugPrint('🎬 [indo:$source] gagal: $e');
      return null;
    }
  }

  /// Ambil daftar pilihan **download** (per kualitas) untuk episode — dari
  /// `data.downloadUrl.formats[].qualities[].urls[]`. Per kualitas dipilih 1
  /// host: **Pixeldrain** (direct → unduh in-app) diutamakan; kalau tak ada,
  /// host pertama (Acefile/Filedon/dll) dengan `direct: false` → dibuka di
  /// browser. Prefer format MP4 (kompatibel better_player).
  /// Return list kosong kalau gagal / tak ada opsi (caller fallback ke stream).
  Future<List<DownloadOption>> fetchDownloadOptions({
    required int anilistId,
    required String animeTitle,
    required int episodeNumber,
    String source = 'samehadaku',
    List<String> altTitles = const [],
  }) async {
    final candidates = _titleCandidates(animeTitle, altTitles);
    if (candidates.isEmpty) return const [];

    try {
      final episodeId = await _resolveEpisodeId(
        source: source,
        anilistId: anilistId,
        candidates: candidates,
        episodeNumber: episodeNumber,
      );
      if (episodeId == null) return const [];

      final res = await _dio.get<dynamic>(
        '$_base/$source/episode/$episodeId',
        options: _opts,
      );
      final data = _dataObject(res);
      final formats =
          (_asMap(data?['downloadUrl'])?['formats'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          const [];
      if (formats.isEmpty) return const [];

      // Prefer format MP4 dulu, lalu sisanya.
      bool isMp4(Map<String, dynamic> f) =>
          ((f['title'] as String?) ?? '').toLowerCase().contains('mp4');
      final ordered = [
        ...formats.where(isMp4),
        ...formats.where((f) => !isMp4(f)),
      ];

      final byQuality = <String, DownloadOption>{};
      for (final f in ordered) {
        final qualities =
            (f['qualities'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        for (final q in qualities) {
          final qLabel = ((q['title'] as String?) ?? '').trim();
          if (qLabel.isEmpty || byQuality.containsKey(qLabel)) continue;
          final urls =
              (q['urls'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
          if (urls.isEmpty) continue;

          // Prefer host directly-downloadable (Pixeldrain) → unduh in-app.
          // Kalau tak ada, ambil host pertama → dibuka di browser (coverage
          // lebih luas: Acefile/Filedon/Krakenfile/Vidhide).
          DownloadOption? pick;
          for (final u in urls) {
            final page = (u['url'] as String?)?.trim() ?? '';
            if (page.isEmpty) continue;
            final direct = DownloadOption.resolvePixeldrain(page);
            final host = (u['title'] as String?)?.trim();
            if (direct != null) {
              pick = DownloadOption(
                quality: qLabel,
                url: direct,
                host: (host?.isNotEmpty ?? false) ? host! : 'Pixeldrain',
              );
              break; // Pixeldrain = terbaik, stop.
            }
            // Simpan host pertama sebagai kandidat browser (kalau belum ada).
            pick ??= DownloadOption(
              quality: qLabel,
              url: page,
              host: (host?.isNotEmpty ?? false) ? host! : 'Host',
              direct: false,
            );
          }
          if (pick != null) byQuality[qLabel] = pick;
        }
      }

      final out = byQuality.values.toList()
        ..sort(
          (a, b) => _qualityNum(b.quality).compareTo(_qualityNum(a.quality)),
        );
      return out;
    } catch (e) {
      debugPrint('🎬 [indo:$source] download options gagal: $e');
      return const [];
    }
  }

  /// Angka kualitas dari label ("720p" → 720). 0 kalau tak ada angka.
  static int _qualityNum(String q) =>
      int.tryParse(RegExp(r'(\d+)').firstMatch(q)?.group(1) ?? '') ?? 0;

  /// Gabung judul utama + alternatif + varian bersih jadi daftar query unik,
  /// dibatasi [_maxSearchQueries] supaya latency terjaga.
  List<String> _titleCandidates(String primary, List<String> alts) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in [primary, ...alts]) {
      for (final v in _searchVariants(raw)) {
        final key = v.toLowerCase();
        if (key.isEmpty || !seen.add(key)) continue;
        out.add(v);
        if (out.length >= _maxSearchQueries) return out;
      }
    }
    return out;
  }

  /// Maks query search berbeda per (anime, episode) — batasi beban + latency.
  static const _maxSearchQueries = 4;

  // ─── Step 1+2: resolve episodeId (dengan cache) ─────────────────────────

  Future<String?> _resolveEpisodeId({
    required String source,
    required int anilistId,
    required List<String> candidates,
    required int episodeNumber,
  }) async {
    final cacheKey = '$source:$anilistId:$episodeNumber';
    final cached = _episodeIdCache[cacheKey];
    if (cached != null) return cached;

    // Coba tiap kandidat judul sampai ketemu animeId + episodeId.
    for (final title in candidates) {
      final animeId = await _searchAnimeId(source: source, title: title);
      if (animeId == null) continue;

      final episodeId = await _findEpisodeId(
        source: source,
        animeId: animeId,
        episodeNumber: episodeNumber,
      );
      if (episodeId != null) {
        _episodeIdCache[cacheKey] = episodeId;
        return episodeId;
      }
    }
    return null;
  }

  /// Varian judul untuk search: judul asli + tanpa klausa setelah `:` +
  /// tanpa suffix `Season N`/`Part N`/`(tahun)` + versi tanpa tanda baca.
  /// Dedupe, urut dari paling spesifik. Pure → mudah di-test.
  static List<String> _searchVariants(String raw) {
    final base = raw.trim();
    if (base.isEmpty) return const [];
    final out = <String>[];
    final seen = <String>{};
    void add(String s) {
      final t = s.trim();
      final key = t.toLowerCase();
      if (t.isEmpty || !seen.add(key)) return;
      out.add(t);
    }

    add(base);
    // Buang klausa setelah ":" (mis. "Title: Subtitle" → "Title").
    if (base.contains(':')) add(base.split(':').first);
    // Buang suffix season/part/tahun.
    final stripped = base
        .replaceAll(
          RegExp(
            r'\b(\d+(st|nd|rd|th)\s+season|season\s+\d+|part\s+\d+)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\(\d{4}\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    add(stripped);
    return out;
  }

  /// Step 1 — `GET /{source}/search?q={title}` → animeId hasil pertama.
  Future<String?> _searchAnimeId({
    required String source,
    required String title,
  }) async {
    final normalized = '$source:${title.trim().toLowerCase()}';
    final cached = _animeIdCache[normalized];
    if (cached != null) return cached;

    final res = await _dio.get<dynamic>(
      '$_base/$source/search',
      queryParameters: {'q': title},
      options: _opts,
    );
    final data = _dataObject(res);
    final animeList = data?['animeList'] as List?;
    if (animeList == null || animeList.isEmpty) return null;

    // Pilih match TERBAIK (token-overlap), bukan asal hasil pertama — kurangi
    // salah anime saat search balikkan banyak kandidat. Di bawah ambang →
    // fallback ke hasil pertama (perilaku lama).
    final entries = animeList.cast<Map<String, dynamic>>();
    final queryTokens = _tokens(title);
    Map<String, dynamic> best = entries.first;
    double bestScore = -1;
    int bestExtra =
        1 << 30; // tie-break: makin sedikit token ekstra makin mirip
    for (final e in entries) {
      final cand = _tokens((e['title'] as String?) ?? '');
      final score = _titleScore(queryTokens, cand);
      if (score > bestScore ||
          (score == bestScore && cand.length < bestExtra)) {
        bestScore = score;
        bestExtra = cand.length;
        best = e;
      }
    }
    final picked = bestScore >= 0.34 ? best : entries.first;
    final id = picked['animeId'] as String?;
    if (id != null && id.isNotEmpty) _animeIdCache[normalized] = id;
    return id;
  }

  /// Token judul ternormalisasi (lowercase, hanya alfanumerik).
  static Set<String> _tokens(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toSet();

  /// Skor kemiripan = irisan / token query (0..1).
  static double _titleScore(Set<String> query, Set<String> candidate) {
    if (query.isEmpty) return 0;
    final overlap = query.intersection(candidate).length;
    return overlap / query.length;
  }

  /// Step 2 — `GET /{source}/anime/{animeId}` → episodeId untuk episode ke-N.
  ///
  /// Episode title biasanya "... Episode 12 Subtitle Indonesia". Cocokkan
  /// nomor lewat regex. List sering urut terbaru→lama, jadi iterate semua.
  Future<String?> _findEpisodeId({
    required String source,
    required String animeId,
    required int episodeNumber,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_base/$source/anime/$animeId',
      options: _opts,
    );
    final data = _dataObject(res);
    final episodeList = data?['episodeList'] as List?;
    if (episodeList == null || episodeList.isEmpty) return null;

    final eps = episodeList.cast<Map<String, dynamic>>();
    for (final ep in eps) {
      final epId = (ep['episodeId'] as String?) ?? '';
      // Cocokkan nomor dari episodeId dulu (mis. "naruto-episode-12"), lalu
      // dari title. title bisa String ("... Episode 12 ...") ATAU int (Sanka)
      // → baca aman via toString().
      final fromId = _episodeIdNumRegex.firstMatch(epId);
      final titleStr = ep['title']?.toString() ?? '';
      final fromTitle = _episodeNumRegex.firstMatch(titleStr);
      final num = fromId != null
          ? int.tryParse(fromId.group(1)!)
          : (fromTitle != null ? int.tryParse(fromTitle.group(1)!) : null);
      if (num == episodeNumber && epId.isNotEmpty) return epId;
    }

    // Fallback: list biasanya descending (ep terbesar di index 0). Ambil dari
    // belakang sesuai nomor (episode 1 = elemen terakhir).
    final idxFromEnd = eps.length - episodeNumber;
    if (idxFromEnd >= 0 && idxFromEnd < eps.length) {
      return eps[idxFromEnd]['episodeId'] as String?;
    }
    return null;
  }

  static final _episodeNumRegex = RegExp(
    r'episode\s+(\d+)',
    caseSensitive: false,
  );

  /// Nomor episode dari episodeId (mis. `naruto-kecil-episode-1` → 1).
  static final _episodeIdNumRegex = RegExp(
    r'episode-(\d+)',
    caseSensitive: false,
  );

  // ─── Step 3+4: episode detail + resolve server ──────────────────────────

  Future<IndoFetchResult?> _fetchEpisode({
    required String source,
    required String episodeId,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_base/$source/episode/$episodeId',
      options: _opts,
    );
    final data = _dataObject(res);
    if (data == null) return null;

    final headers = <String, String>{'Referer': '$_base/'};

    // Kumpulkan serverId dari semua quality. Sanka pakai key `qualities`,
    // wajik pakai `qualityList` → dukung dua-duanya.
    final serverIds = <String>[];
    final server = _asMap(data['server']);
    final qualityList =
        (server?['qualities'] ?? server?['qualityList']) as List?;
    if (qualityList != null) {
      for (final q in qualityList.cast<Map<String, dynamic>>()) {
        final serverList = q['serverList'] as List?;
        if (serverList == null) continue;
        for (final s in serverList.cast<Map<String, dynamic>>()) {
          final id = s['serverId'] as String?;
          if (id != null && id.isNotEmpty) serverIds.add(id);
        }
      }
    }

    // Probe beberapa server cari direct `.mp4`/`.m3u8`.
    final directSources = <StreamSource>[];
    var probed = 0;
    for (final id in serverIds) {
      if (probed >= _maxServerProbe) break;
      probed++;
      try {
        final url = await _resolveServerUrl(source: source, serverId: id);
        if (url == null) continue;
        final lower = url.toLowerCase();
        if (lower.contains('.m3u8')) {
          directSources.add(StreamSource(url: url, type: 'hls'));
        } else if (lower.contains('.mp4')) {
          directSources.add(StreamSource(url: url, type: 'mp4'));
        }
      } catch (_) {
        // skip server ini
      }
    }

    if (directSources.isNotEmpty) {
      return IndoFetchResult(sources: directSources, headers: headers);
    }

    // Tidak ada direct → pakai embed (defaultStreamingUrl) untuk WebView.
    final embed = (data['defaultStreamingUrl'] as String?)?.trim();
    if (embed != null && embed.isNotEmpty) {
      return IndoFetchResult(embedUrl: embed, headers: headers);
    }
    return null;
  }

  /// Step 4 — `GET /{source}/server/{serverId}` → `data.url`.
  Future<String?> _resolveServerUrl({
    required String source,
    required String serverId,
  }) async {
    final res = await _dio.get<dynamic>(
      '$_base/$source/server/$serverId',
      options: _opts,
    );
    final data = _dataObject(res);
    final url = data?['url'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Options get _opts => Options(
    sendTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    validateStatus: (s) => s != null && s < 500,
  );

  void resetCache() {
    _episodeIdCache.clear();
    _animeIdCache.clear();
  }

  /// Expose varian judul untuk unit test.
  @visibleForTesting
  static List<String> debugSearchVariants(String raw) => _searchVariants(raw);
}

/// Cast aman ke `Map<String, dynamic>` — return null kalau bukan Map (mis.
/// API balas String/HTML). Mencegah `TypeError` cast String→Map saat scraper
/// API mengembalikan body tak terduga.
Map<String, dynamic>? _asMap(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// Ambil objek `data` dari response wajik-anime-api dengan aman. Body bisa saja
/// String (pesan error / halaman HTML) bukan objek JSON → jangan sampai lempar.
Map<String, dynamic>? _dataObject(Response<dynamic> res) {
  final body = res.data;
  return body is Map ? _asMap(body['data']) : null;
}

final indoAnimeClientProvider = Provider<IndoAnimeClient>((ref) {
  final dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Accept-Language': 'id-ID,id;q=0.9,en;q=0.8',
      },
    ),
  );
  return IndoAnimeClient(dio);
});
