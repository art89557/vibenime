/// Domain model untuk satu post diskusi anime.
///
/// Mapping ke tabel `anime_discussions` di Supabase.
class Discussion {
  const Discussion({
    required this.id,
    required this.animeId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final int animeId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;

  factory Discussion.fromJson(Map<String, dynamic> json) {
    return Discussion(
      id: json['id'] as String,
      animeId: (json['anime_id'] as num).toInt(),
      userId: json['user_id'] as String,
      username: json['username'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
