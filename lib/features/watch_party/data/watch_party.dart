/// Domain model untuk active watch party session.
///
/// Mapping ke tabel `watch_parties` di Supabase. Lihat
/// `sql/watch_party.sql` untuk schema lengkap.
///
/// Lifecycle:
/// 1. Host create party → row baru dengan `is_active=true`
/// 2. Host update playback (position+isPlaying) tiap 2 detik
/// 3. Host end party → `is_active=false` (atau row di-delete)
/// 4. Auto-cleanup: kalau `updated_at` >30 menit lalu, anggap stale
class WatchParty {
  const WatchParty({
    required this.id,
    required this.hostUserId,
    required this.hostUsername,
    required this.animeId,
    required this.episodeNumber,
    required this.currentPositionSeconds,
    required this.isPlaying,
    required this.isActive,
    required this.participantCount,
    required this.startedAt,
    required this.updatedAt,
  });

  final String id;
  final String hostUserId;
  final String hostUsername;
  final int animeId;
  final int episodeNumber;
  final int currentPositionSeconds;
  final bool isPlaying;
  final bool isActive;
  final int participantCount;
  final DateTime startedAt;
  final DateTime updatedAt;

  Duration get currentPosition => Duration(seconds: currentPositionSeconds);

  /// True kalau party "stale" — host tidak update >30 detik (mungkin disconnect).
  bool get isStale {
    final now = DateTime.now();
    return now.difference(updatedAt).inSeconds > 30;
  }

  factory WatchParty.fromJson(Map<String, dynamic> json) {
    return WatchParty(
      id: json['id'] as String,
      hostUserId: json['host_user_id'] as String,
      hostUsername: json['host_username'] as String,
      animeId: (json['anime_id'] as num).toInt(),
      episodeNumber: (json['episode_number'] as num).toInt(),
      currentPositionSeconds:
          (json['current_position_seconds'] as num?)?.toInt() ?? 0,
      isPlaying: json['is_playing'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 1,
      startedAt: DateTime.parse(json['started_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  WatchParty copyWith({
    int? currentPositionSeconds,
    bool? isPlaying,
    bool? isActive,
    int? participantCount,
    DateTime? updatedAt,
  }) {
    return WatchParty(
      id: id,
      hostUserId: hostUserId,
      hostUsername: hostUsername,
      animeId: animeId,
      episodeNumber: episodeNumber,
      currentPositionSeconds:
          currentPositionSeconds ?? this.currentPositionSeconds,
      isPlaying: isPlaying ?? this.isPlaying,
      isActive: isActive ?? this.isActive,
      participantCount: participantCount ?? this.participantCount,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
