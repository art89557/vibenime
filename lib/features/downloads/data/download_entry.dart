/// Domain model untuk satu video yang sudah di-download offline.
///
/// Storage:
/// - Hive box `downloads`, key = `"${animeId}:${episodeId}"`
/// - File fisik di app documents dir, path tersimpan di [localPath]
class DownloadEntry {
  const DownloadEntry({
    required this.animeId,
    required this.episodeId,
    required this.episodeNumber,
    required this.animeTitle,
    required this.episodeTitle,
    required this.coverImage,
    required this.localPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.sourceUrl,
  });

  /// AniList anime ID.
  final int animeId;

  /// Format `ep-{anilistId}-{number}`.
  final String episodeId;

  final int episodeNumber;

  /// Title anime (cached dari AniList saat download — biar bisa ditampilkan
  /// offline tanpa hit API).
  final String animeTitle;

  /// Title episode (kalau ada). Kosong kalau generic "Episode N".
  final String episodeTitle;

  /// URL cover anime untuk thumbnail di list (cached).
  final String coverImage;

  /// Absolute path ke file .mp4 di device.
  final String localPath;

  /// Ukuran file dalam bytes (untuk display "150 MB" dll).
  final int fileSizeBytes;

  /// Timestamp saat download selesai.
  final DateTime downloadedAt;

  /// URL asli source — disimpan untuk re-download / debug.
  final String sourceUrl;

  /// Composite key untuk Hive (consistent dengan history pattern).
  String get hiveKey => '$animeId:$episodeId';

  /// Format file size ke human-readable string ("150.2 MB").
  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
    'animeId': animeId,
    'episodeId': episodeId,
    'episodeNumber': episodeNumber,
    'animeTitle': animeTitle,
    'episodeTitle': episodeTitle,
    'coverImage': coverImage,
    'localPath': localPath,
    'fileSizeBytes': fileSizeBytes,
    'downloadedAt': downloadedAt.toIso8601String(),
    'sourceUrl': sourceUrl,
  };

  factory DownloadEntry.fromJson(Map<dynamic, dynamic> json) {
    return DownloadEntry(
      animeId: (json['animeId'] as num).toInt(),
      episodeId: json['episodeId'] as String,
      episodeNumber: (json['episodeNumber'] as num).toInt(),
      animeTitle: (json['animeTitle'] as String?) ?? '?',
      episodeTitle: (json['episodeTitle'] as String?) ?? '',
      coverImage: (json['coverImage'] as String?) ?? '',
      localPath: json['localPath'] as String,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      sourceUrl: (json['sourceUrl'] as String?) ?? '',
    );
  }
}
