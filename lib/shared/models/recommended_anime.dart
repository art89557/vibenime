/// Slim model untuk anime di section "Kamu mungkin suka" (rekomendasi AniList).
/// Berasal dari `Media.recommendations.nodes[].mediaRecommendation`.
class RecommendedAnime {
  const RecommendedAnime({
    required this.id,
    required this.title,
    required this.coverImage,
    this.averageScore,
  });

  final int id;
  final String title;
  final String coverImage;
  final int? averageScore;

  /// Parse dari `recommendations.nodes[]` AniList. Skip node tanpa
  /// `mediaRecommendation` (media yang dihapus) atau tanpa id. Dedupe by id.
  static List<RecommendedAnime> fromAniListNodes(List<dynamic> nodes) {
    final result = <RecommendedAnime>[];
    final seen = <int>{};
    for (final raw in nodes) {
      final node = _asMap(raw);
      final media = _asMap(node?['mediaRecommendation']);
      if (media == null) continue;
      final id = (media['id'] as num?)?.toInt();
      if (id == null || !seen.add(id)) continue;

      final title = _asMap(media['title']) ?? const {};
      final cover = _asMap(media['coverImage']) ?? const {};
      result.add(
        RecommendedAnime(
          id: id,
          title:
              (title['english'] ?? title['romaji'] ?? title['native'] ?? '?')
                  as String,
          coverImage: (cover['medium'] ?? cover['large'] ?? '') as String,
          averageScore: (media['averageScore'] as num?)?.toInt(),
        ),
      );
    }
    return result;
  }

  /// Cast aman ke `Map<String, dynamic>` — return null kalau bukan Map (mis.
  /// literal map bertipe sempit dari test, atau body tak terduga dari API).
  static Map<String, dynamic>? _asMap(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : null;
}
