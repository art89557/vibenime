/// Status menonton untuk entry di "My List" lokal.
///
/// Match AniList list status (CURRENT/COMPLETED/PLANNING) tapi pure local
/// — disimpan di Hive box `favorites`.
enum WatchStatus {
  /// Anime yang sedang ditonton user (>=1 episode pernah ditonton tapi belum selesai).
  watching('WATCHING', 'Watching'),

  /// Selesai ditonton — episode terakhir sudah finished.
  completed('COMPLETED', 'Completed'),

  /// Belum mulai — di-bookmark tapi belum ditonton.
  planning('PLANNING', 'Planning');

  const WatchStatus(this.code, this.label);

  /// Stored as String code di Hive (mis. "WATCHING") — backwards compatible
  /// kalau enum order berubah.
  final String code;

  /// User-facing label.
  final String label;

  static WatchStatus fromCode(String? code) {
    for (final s in WatchStatus.values) {
      if (s.code == code) return s;
    }
    return WatchStatus.planning;
  }
}

/// Satu entry "My List" — anime + status + waktu ditambah.
///
/// Disimpan local di Hive box `favorites` — key=`animeId.toString()`,
/// value=`toJson()`. Tidak butuh akun, tidak sync ke server.
class FavoriteEntry {
  const FavoriteEntry({
    required this.animeId,
    required this.title,
    required this.coverImage,
    required this.addedAt,
    this.status = WatchStatus.planning,
    this.totalEpisodes,
  });

  final int animeId;
  final String title;
  final String coverImage;
  final DateTime addedAt;

  /// Status nonton: planning (default) / watching / completed.
  final WatchStatus status;

  /// Total episodes (snapshot dari Anime.episodes saat di-add). Untuk render
  /// progress bar "EP X / Y" tanpa fetch ulang AniList.
  final int? totalEpisodes;

  FavoriteEntry copyWith({WatchStatus? status, int? totalEpisodes}) {
    return FavoriteEntry(
      animeId: animeId,
      title: title,
      coverImage: coverImage,
      addedAt: addedAt,
      status: status ?? this.status,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
    );
  }

  static String storageKey(int animeId) => animeId.toString();

  Map<String, dynamic> toJson() => {
    'animeId': animeId,
    'title': title,
    'coverImage': coverImage,
    'addedAt': addedAt.millisecondsSinceEpoch,
    'status': status.code,
    'totalEpisodes': totalEpisodes,
  };

  factory FavoriteEntry.fromJson(Map<dynamic, dynamic> json) {
    return FavoriteEntry(
      animeId: json['animeId'] as int,
      title: (json['title'] as String?) ?? '',
      coverImage: (json['coverImage'] as String?) ?? '',
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['addedAt'] as int?) ?? 0,
      ),
      status: WatchStatus.fromCode(json['status'] as String?),
      totalEpisodes: (json['totalEpisodes'] as num?)?.toInt(),
    );
  }
}
