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
  });

  final List<StreamSource> sources;
  final List<SubtitleTrack> subtitles;
  final Map<String, String> headers;

  /// Kalau set, player render YoutubePlayer dengan video ID ini.
  /// Diisi dari AniList trailer (untuk anime yang ada trailer official-nya).
  final String? youtubeVideoId;

  bool get isYoutube => youtubeVideoId != null && youtubeVideoId!.isNotEmpty;

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
  const StreamSource({
    required this.url,
    this.type,
    this.quality,
  });

  final String url;
  final String? type;
  final String? quality;

  bool get isHls =>
      (type?.toLowerCase() == 'hls') || url.toLowerCase().contains('.m3u8');
}

class SubtitleTrack {
  const SubtitleTrack({
    required this.url,
    this.language,
  });

  final String url;
  final String? language;
}

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
