/// Episode untuk player.
///
/// Di MVP, episode disintesa dari `episodeCount` AniList (lihat
/// `SampleStreamingRepository`). Di production, model ini siap di-mapping
/// dari real provider (cukup bikin factory `Episode.fromXxxJson`).
class Episode {
  const Episode({
    required this.id,
    required this.number,
    this.title,
    this.thumbnail,
  });

  final String id;
  final int number;
  final String? title;
  final String? thumbnail;
}
