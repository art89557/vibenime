/// Satu record history menonton: anime + episode + posisi terakhir.
class HistoryEntry {
  const HistoryEntry({
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.positionSeconds,
    required this.watchedAt,
    this.durationSeconds,
  });

  final int animeId;
  final String episodeId;
  final int episodeNumber;
  final int positionSeconds;
  final int? durationSeconds;
  final DateTime watchedAt;

  Duration get position => Duration(seconds: positionSeconds);
  Duration? get duration =>
      durationSeconds == null ? null : Duration(seconds: durationSeconds!);

  /// Persen progress (0.0 - 1.0). Null kalau duration belum diketahui.
  double? get progressFraction {
    final d = durationSeconds;
    if (d == null || d == 0) return null;
    return (positionSeconds / d).clamp(0.0, 1.0);
  }

  /// Anggap "sudah selesai" kalau progress > 90% atau sisa < 30 detik.
  bool get isFinished {
    final d = durationSeconds;
    if (d == null) return false;
    return positionSeconds >= d - 30 || (progressFraction ?? 0) >= 0.9;
  }

  static String storageKey(int animeId, String episodeId) =>
      '$animeId:$episodeId';

  Map<String, dynamic> toJson() => {
        'animeId': animeId,
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
        'watchedAt': watchedAt.millisecondsSinceEpoch,
      };

  factory HistoryEntry.fromJson(Map<dynamic, dynamic> json) {
    return HistoryEntry(
      animeId: (json['animeId'] as num).toInt(),
      episodeId: json['episodeId'] as String,
      episodeNumber: (json['episodeNumber'] as num).toInt(),
      positionSeconds: (json['positionSeconds'] as num).toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      watchedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['watchedAt'] as num).toInt(),
      ),
    );
  }
}
