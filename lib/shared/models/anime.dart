import '../../core/settings/title_language.dart';
import 'character.dart';
import 'recommended_anime.dart';
import 'related_anime.dart';

/// Info episode upcoming dari AniList `nextAiringEpisode`.
class NextAiringEpisode {
  const NextAiringEpisode({required this.episode, required this.airingAt});

  /// Nomor episode yang akan tayang berikutnya.
  final int episode;

  /// Unix epoch (seconds) waktu tayang.
  final int airingAt;

  DateTime get airingDateTime =>
      DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);
}

/// Streaming episode dari AniList — punya thumbnail asli (Crunchyroll dll).
class StreamingEpisode {
  const StreamingEpisode({
    required this.title,
    this.thumbnail,
    this.url,
    this.site,
  });

  final String title;
  final String? thumbnail;
  final String? url;
  final String? site;

  /// Extract nomor episode dari title kalau format-nya "Episode 5 - ...".
  /// Return `null` kalau tidak match.
  int? get episodeNumber {
    final match = RegExp(
      r'Episode\s+(\d+)',
      caseSensitive: false,
    ).firstMatch(title);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}

/// Domain model anime (gabungan dari AniList).
class Anime {
  const Anime({
    required this.id,
    required this.title,
    required this.coverImage,
    this.idMal,
    this.bannerImage,
    this.description,
    this.format,
    this.status,
    this.episodes,
    this.duration,
    this.averageScore,
    this.popularity,
    this.genres = const [],
    this.season,
    this.seasonYear,
    this.studio,
    this.studios = const [],
    this.trailerYoutubeId,
    this.relations = const [],
    this.recommendations = const [],
    this.characters = const [],
    this.streamingEpisodes = const [],
    this.nextAiringEpisode,
    this.englishTitle,
    this.romajiTitle,
    this.nativeTitle,
  });

  final int id;

  /// MyAnimeList ID (dari AniList `idMal`) — dipakai AniSkip untuk timestamp
  /// intro/outro. Null kalau AniList tidak punya mapping MAL.
  final int? idMal;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String? nativeTitle;

  /// Judul untuk DITAMPILKAN sesuai preferensi global [TitlePref.current]
  /// (Romaji/English) dengan fallback aman. Pakai ini di UI alih-alih [title].
  String get displayTitle {
    final preferred = TitlePref.current == TitleLanguage.english
        ? englishTitle
        : romajiTitle;
    final fallback = TitlePref.current == TitleLanguage.english
        ? romajiTitle
        : englishTitle;
    final result = (preferred?.trim().isNotEmpty ?? false)
        ? preferred!
        : (fallback?.trim().isNotEmpty ?? false)
        ? fallback!
        : title;
    return result.isNotEmpty ? result : (nativeTitle ?? title);
  }

  final String coverImage;
  final String? bannerImage;
  final String? description;
  final String? format;
  final String? status;
  final int? episodes;
  final int? duration;
  final int? averageScore;
  final int? popularity;
  final List<String> genres;
  final String? season;
  final int? seasonYear;
  final String? studio;

  /// Daftar nama studio (untuk anime collab/multi-studio). `studio` singular
  /// di atas = first element. Kalau cuma satu studio, list ini punya 1 item.
  final List<String> studios;

  /// YouTube video ID dari AniList trailer (kalau site == "youtube").
  final String? trailerYoutubeId;

  /// Anime terkait (sekuel, prekuel, dll). Diparse dari `relations.edges`.
  final List<RelatedAnime> relations;

  /// Rekomendasi AniList ("Kamu mungkin suka"). Diparse dari
  /// `recommendations.nodes[].mediaRecommendation`.
  final List<RecommendedAnime> recommendations;

  /// Daftar karakter (sorted MAIN → SUPPORTING → BACKGROUND).
  final List<Character> characters;

  /// Episode dengan thumbnail asli (kalau tersedia, biasanya cuma sebagian).
  final List<StreamingEpisode> streamingEpisodes;

  /// Episode upcoming + airingAt (epoch). Null kalau anime sudah finished.
  final NextAiringEpisode? nextAiringEpisode;

  /// Index `streamingEpisodes` ke peta `episodeNumber → thumbnail URL`.
  /// Konsumer (mis. EpisodesGrid) bisa lookup cepat.
  Map<int, String?> get episodeThumbnails {
    final map = <int, String?>{};
    for (final se in streamingEpisodes) {
      final n = se.episodeNumber;
      if (n != null) map[n] = se.thumbnail;
    }
    return map;
  }

  /// True kalau anime sedang tayang/airing.
  bool get isReleasing => status == 'RELEASING';

  factory Anime.fromAniListMedia(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>? ?? const {};
    final cover = json['coverImage'] as Map<String, dynamic>? ?? const {};
    final studios =
        (json['studios'] as Map<String, dynamic>?)?['nodes'] as List<dynamic>?;

    // Trailer hanya valid kalau site == "youtube".
    String? trailerId;
    final trailer = json['trailer'] as Map<String, dynamic>?;
    if (trailer != null && trailer['site'] == 'youtube') {
      trailerId = trailer['id'] as String?;
    }

    // Parse relations (kalau ada di response).
    final relationsRaw =
        (json['relations'] as Map<String, dynamic>?)?['edges'] as List?;
    final relations = relationsRaw == null
        ? const <RelatedAnime>[]
        : RelatedAnime.fromAniListEdges(relationsRaw);

    // Parse recommendations (kalau ada di response detail).
    final recommendationsRaw =
        (json['recommendations'] as Map<String, dynamic>?)?['nodes'] as List?;
    final recommendations = recommendationsRaw == null
        ? const <RecommendedAnime>[]
        : RecommendedAnime.fromAniListNodes(recommendationsRaw);

    // Parse characters (kalau ada di response).
    final charactersRaw =
        (json['characters'] as Map<String, dynamic>?)?['edges'] as List?;
    final characters = charactersRaw == null
        ? const <Character>[]
        : Character.fromAniListEdges(charactersRaw);

    // Parse streamingEpisodes (kalau ada).
    final streamingEpsRaw = json['streamingEpisodes'] as List?;
    final streamingEps = (streamingEpsRaw ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (e) => StreamingEpisode(
            title: (e['title'] as String?) ?? '',
            thumbnail: e['thumbnail'] as String?,
            url: e['url'] as String?,
            site: e['site'] as String?,
          ),
        )
        .toList();

    // Parse nextAiringEpisode (kalau ada — null untuk anime finished).
    NextAiringEpisode? nextAiring;
    final nextAiringRaw = json['nextAiringEpisode'] as Map<String, dynamic>?;
    if (nextAiringRaw != null) {
      nextAiring = NextAiringEpisode(
        episode: (nextAiringRaw['episode'] as num).toInt(),
        airingAt: (nextAiringRaw['airingAt'] as num).toInt(),
      );
    }

    return Anime(
      id: (json['id'] as num).toInt(),
      idMal: (json['idMal'] as num?)?.toInt(),
      title:
          (title['english'] ?? title['romaji'] ?? title['native'] ?? '?')
              as String,
      englishTitle: title['english'] as String?,
      romajiTitle: title['romaji'] as String?,
      nativeTitle: title['native'] as String?,
      coverImage: (cover['large'] ?? cover['medium'] ?? '') as String,
      bannerImage: json['bannerImage'] as String?,
      description: json['description'] as String?,
      format: json['format'] as String?,
      status: json['status'] as String?,
      episodes: (json['episodes'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      averageScore: (json['averageScore'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      genres: ((json['genres'] as List?) ?? const []).cast<String>(),
      season: json['season'] as String?,
      seasonYear: (json['seasonYear'] as num?)?.toInt(),
      studio: studios != null && studios.isNotEmpty
          ? (studios.first as Map<String, dynamic>)['name'] as String?
          : null,
      studios: studios == null
          ? const <String>[]
          : studios
                .map(
                  (n) => ((n as Map<String, dynamic>)['name'] as String?) ?? '',
                )
                .where((s) => s.isNotEmpty)
                .toList(),
      trailerYoutubeId: trailerId,
      relations: relations,
      recommendations: recommendations,
      characters: characters,
      streamingEpisodes: streamingEps,
      nextAiringEpisode: nextAiring,
    );
  }
}
