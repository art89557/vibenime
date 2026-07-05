/// Payload streaming untuk player.
///
/// Punya 2 mode: YouTube trailer (preferred) atau sample HLS (fallback).
/// PlayerScreen branch berdasarkan `isYoutube`.
class StreamPayload {
  const StreamPayload({
    this.sources = const [],
    this.subtitles = const [],
    this.headers = const {},
    this.youtubeVideoId,
    this.embedUrl,
    this.sourceLabel,
    this.sourceId,
    this.introStart,
    this.introEnd,
    this.outroStart,
    this.outroEnd,
  });

  final List<StreamSource> sources;
  final List<SubtitleTrack> subtitles;
  final Map<String, String> headers;

  /// Kalau set, player render YoutubePlayer dengan video ID ini.
  /// Diisi dari AniList trailer (untuk anime yang ada trailer official-nya).
  final String? youtubeVideoId;

  /// Kalau set, player render via `WebView` (iframe embed) — dipakai untuk
  /// source Otakudesu/Samehadaku yang return URL embed host (Doodstream,
  /// desustream, dll) BUKAN direct `.mp4`/`.m3u8`. `better_player` tidak bisa
  /// play iframe, jadi WebView yang load halaman embed-nya.
  final String? embedUrl;

  /// Label user-facing untuk source picker dropdown — e.g. "Otakudesu",
  /// "Kuramanime", "YouTube Trailer", "Local Download", "Mux Sample".
  /// Null kalau dari Supabase video catalog (admin-curated).
  final String? sourceLabel;

  /// Source identifier (matching `AnimeSource.id`) — dipakai untuk match
  /// user pilihan di dropdown vs payload list.
  final String? sourceId;

  /// Timestamp intro/outro (detik) — diisi source yang punya data skip
  /// (mis. Miruro). Dipakai tombol "Skip Intro/Outro" + auto-skip.
  /// Null kalau source tidak menyediakan (fallback ke AniSkip).
  final double? introStart;
  final double? introEnd;
  final double? outroStart;
  final double? outroEnd;

  bool get hasIntro => introStart != null && introEnd != null;
  bool get hasOutro => outroStart != null && outroEnd != null;

  bool get isYoutube => youtubeVideoId != null && youtubeVideoId!.isNotEmpty;

  /// True kalau payload ini embed iframe (di-render via WebView, bukan
  /// better_player). Diisi source Otakudesu/Samehadaku yang hanya kasih embed.
  bool get isEmbed => embedUrl != null && embedUrl!.isNotEmpty;

  /// Pakai source pertama yang HLS, fallback first.
  StreamSource? get primarySource {
    if (sources.isEmpty) return null;
    for (final s in sources) {
      if (s.isHls) return s;
    }
    return sources.first;
  }

  /// Pilih subtitle Indonesia jika ada, fallback English.
  SubtitleTrack? get preferredIndonesianSubtitle {
    SubtitleTrack? indo;
    SubtitleTrack? eng;
    for (final t in subtitles) {
      final lang = t.language?.toLowerCase() ?? '';
      if (lang.contains('indo')) {
        indo = t;
      } else if (lang.contains('english') || lang == 'en') {
        eng = t;
      }
    }
    return indo ?? eng ?? subtitles.firstOrNull;
  }
}

class StreamSource {
  const StreamSource({required this.url, this.type, this.quality});

  final String url;
  final String? type;
  final String? quality;

  bool get isHls =>
      (type?.toLowerCase() == 'hls') || url.toLowerCase().contains('.m3u8');

  /// True kalau source ini local file path (sudah di-download offline),
  /// bukan URL network. Player pakai `BetterPlayerDataSourceType.file`.
  bool get isLocal =>
      url.startsWith('/') ||
      url.startsWith('file://') ||
      (url.length > 1 && url[1] == ':'); // Windows path C:\...
}

class SubtitleTrack {
  const SubtitleTrack({required this.url, this.language});

  final String url;
  final String? language;
}

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
