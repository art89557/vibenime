/// Slim model untuk anime di "Anime Terkait" section.
/// Berasal dari `Media.relations.edges[].node` di AniList.
class RelatedAnime {
  const RelatedAnime({
    required this.id,
    required this.title,
    required this.coverImage,
    required this.relationType,
    this.format,
    this.episodes,
    this.averageScore,
  });

  final int id;
  final String title;
  final String coverImage;

  /// Tipe relasi: SEQUEL, PREQUEL, SIDE_STORY, ALTERNATIVE, dll.
  final String relationType;
  final String? format;
  final int? episodes;
  final int? averageScore;

  /// Hanya tipe ini yang ditampilkan di "Anime Terkait" (skip CHARACTER, dll).
  static const Set<String> displayedRelations = {
    'SEQUEL',
    'PREQUEL',
    'SIDE_STORY',
    'PARENT',
    'ALTERNATIVE',
    'SPIN_OFF',
    'SUMMARY',
  };

  /// Parse dari `relations.edges[]` AniList.
  static List<RelatedAnime> fromAniListEdges(List<dynamic> edges) {
    final result = <RelatedAnime>[];
    for (final raw in edges) {
      final edge = raw as Map<String, dynamic>;
      final node = edge['node'] as Map<String, dynamic>?;
      final relType = edge['relationType'] as String?;
      if (node == null || relType == null) continue;
      if (!displayedRelations.contains(relType)) continue;

      // Hanya tampilkan ANIME (relations bisa berisi MANGA juga).
      final type = node['type'] as String?;
      if (type != null && type != 'ANIME') continue;

      final title = node['title'] as Map<String, dynamic>? ?? const {};
      final cover = node['coverImage'] as Map<String, dynamic>? ?? const {};

      result.add(
        RelatedAnime(
          id: (node['id'] as num).toInt(),
          title: (title['english'] ??
                  title['romaji'] ??
                  title['native'] ??
                  '?') as String,
          coverImage: (cover['medium'] ?? cover['large'] ?? '') as String,
          relationType: relType,
          format: node['format'] as String?,
          episodes: (node['episodes'] as num?)?.toInt(),
          averageScore: (node['averageScore'] as num?)?.toInt(),
        ),
      );
    }
    return result;
  }

  /// Label friendly untuk relationType.
  String get relationLabel {
    switch (relationType) {
      case 'SEQUEL':
        return 'Sekuel';
      case 'PREQUEL':
        return 'Prekuel';
      case 'SIDE_STORY':
        return 'Side Story';
      case 'PARENT':
        return 'Induk';
      case 'ALTERNATIVE':
        return 'Versi Alt.';
      case 'SPIN_OFF':
        return 'Spin-off';
      case 'SUMMARY':
        return 'Summary';
      default:
        return relationType;
    }
  }
}
