import 'related_anime.dart';

/// Domain model anime (gabungan dari AniList).
class Anime {
  const Anime({
    required this.id,
    required this.title,
    required this.coverImage,
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
    this.trailerYoutubeId,
    this.relations = const [],
    this.englishTitle,
    this.nativeTitle,
  });

  final int id;
  final String title;
  final String? englishTitle;
  final String? nativeTitle;
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

  /// YouTube video ID dari AniList trailer (kalau site == "youtube").
  final String? trailerYoutubeId;

  /// Anime terkait (sekuel, prekuel, dll). Diparse dari `relations.edges`.
  final List<RelatedAnime> relations;

  /// True kalau anime sedang tayang/airing.
  bool get isReleasing => status == 'RELEASING';

  factory Anime.fromAniListMedia(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>? ?? const {};
    final cover = json['coverImage'] as Map<String, dynamic>? ?? const {};
    final studios = (json['studios'] as Map<String, dynamic>?)?['nodes']
        as List<dynamic>?;

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

    return Anime(
      id: (json['id'] as num).toInt(),
      title: (title['english'] ?? title['romaji'] ?? title['native'] ?? '?')
          as String,
      englishTitle: title['english'] as String?,
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
      trailerYoutubeId: trailerId,
      relations: relations,
    );
  }
}
