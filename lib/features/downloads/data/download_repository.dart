import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/hive_init.dart';
import 'download_entry.dart';

/// Status dari satu task download yang lagi berjalan.
class DownloadProgress {
  const DownloadProgress({
    required this.animeId,
    required this.episodeId,
    required this.received,
    required this.total,
  });

  final int animeId;
  final String episodeId;

  /// Bytes ter-download sejauh ini.
  final int received;

  /// Total bytes (dari Content-Length header). 0 kalau server tidak kasih.
  final int total;

  /// Fraction 0.0 - 1.0 untuk progress bar UI. Return 0 kalau total=0.
  double get fraction => total <= 0 ? 0 : (received / total).clamp(0.0, 1.0);

  /// True kalau download selesai.
  bool get isComplete => total > 0 && received >= total;
}

/// Repository untuk fitur **Download Offline**.
///
/// **Limitasi:**
/// - Hanya support direct video URL (.mp4, .m3u8) — YouTube tidak bisa
///   karena DRM + ToS.
/// - File disimpan di app documents dir → otomatis ke-clean kalau user
///   uninstall app.
///
/// **Workflow:**
/// 1. [downloadVideo] — terima VideoSource, return Stream progress
/// 2. Saat selesai, save ke Hive box `downloads`
/// 3. [getAll] / [getByEpisodeId] untuk list / lookup
/// 4. [delete] hapus file fisik + entry Hive
class DownloadRepository {
  DownloadRepository(this._dio);

  final Dio _dio;

  Box<Map<dynamic, dynamic>> get _box =>
      Hive.box<Map<dynamic, dynamic>>(HiveBoxes.downloads);

  /// True kalau download file fisik didukung di platform ini.
  /// Web tidak punya filesystem — pakai cek ini sebelum panggil [downloadVideo].
  static bool get isSupported => !kIsWeb;

  /// Lokasi storage download — persistent across launches.
  /// Throw [UnsupportedError] di web (no filesystem).
  Future<Directory> _downloadDir() async {
    if (kIsWeb) {
      throw UnsupportedError(
        'Download offline tidak tersedia di web. Pakai aplikasi mobile/desktop.',
      );
    }
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/vibenime_downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Generate filename dari animeId + episodeId, slugify, append ext.
  String _filename(int animeId, String episodeId, String url) {
    // Extract extension dari URL (.mp4, .m3u8, etc).
    final ext = url.toLowerCase().contains('.m3u8') ? 'm3u8' : 'mp4';
    return '$animeId-$episodeId.$ext';
  }

  /// Download video dari [url] ke local file. Emit [DownloadProgress] tiap
  /// kali ada chunk baru. Saat selesai, return [DownloadEntry] yang sudah
  /// di-save ke Hive.
  ///
  /// Throw exception kalau:
  /// - Network error
  /// - URL invalid / 404
  /// - Storage full
  ///
  /// **Cancel support:** caller bisa kasih [cancelToken] dari `Dio`.
  Stream<DownloadProgress> downloadVideo({
    required int animeId,
    required String episodeId,
    required int episodeNumber,
    required String animeTitle,
    required String episodeTitle,
    required String coverImage,
    required String sourceUrl,
    CancelToken? cancelToken,
  }) async* {
    final dir = await _downloadDir();
    final filename = _filename(animeId, episodeId, sourceUrl);
    final localPath = '${dir.path}/$filename';

    // Stream controller untuk emit progress dari dio onReceiveProgress.
    final controller = StreamController<DownloadProgress>();

    // Forward dio progress ke stream controller.
    void onProgress(int received, int total) {
      if (!controller.isClosed) {
        controller.add(
          DownloadProgress(
            animeId: animeId,
            episodeId: episodeId,
            received: received,
            total: total,
          ),
        );
      }
    }

    // Spawn download dengan dio. Tidak await — biarkan stream emit progress.
    //
    // **Headers browser-like:** Internet Archive (dan beberapa CDN lain)
    // reject request tanpa User-Agent legitimate dengan 401/403. Dengan
    // headers ini, dio terlihat seperti Chrome biasa.
    unawaited(
      _dio
          .download(
            sourceUrl,
            localPath,
            cancelToken: cancelToken,
            onReceiveProgress: onProgress,
            options: Options(
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 400,
              followRedirects: true,
              maxRedirects: 5,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                'Accept': '*/*',
                'Accept-Encoding':
                    'identity', // disable gzip — dio handle stream
                // Referer ke domain asal supaya CDN tidak reject hotlink.
                if (sourceUrl.contains('archive.org'))
                  'Referer': 'https://archive.org/',
              },
            ),
          )
          .then((_) async {
            // Selesai — save Hive entry.
            try {
              final file = File(localPath);
              final size = await file.length();
              final entry = DownloadEntry(
                animeId: animeId,
                episodeId: episodeId,
                episodeNumber: episodeNumber,
                animeTitle: animeTitle,
                episodeTitle: episodeTitle,
                coverImage: coverImage,
                localPath: localPath,
                fileSizeBytes: size,
                downloadedAt: DateTime.now(),
                sourceUrl: sourceUrl,
              );
              await _box.put(entry.hiveKey, entry.toJson());
            } catch (e) {
              debugPrint('Save download entry error: $e');
            }
            if (!controller.isClosed) {
              await controller.close();
            }
          })
          .catchError((e) async {
            debugPrint('Download error: $e');
            // Hapus partial file kalau ada.
            try {
              final f = File(localPath);
              if (f.existsSync()) await f.delete();
            } catch (_) {}
            if (!controller.isClosed) {
              controller.addError(e);
              await controller.close();
            }
          }),
    );

    yield* controller.stream;
  }

  /// Get semua download entry, sorted by latest first.
  List<DownloadEntry> getAll() {
    final keys = _box.keys.toList();
    final entries = <DownloadEntry>[];
    for (final k in keys) {
      final raw = _box.get(k);
      if (raw == null) continue;
      try {
        entries.add(DownloadEntry.fromJson(raw));
      } catch (e) {
        debugPrint('Parse download entry error for $k: $e');
      }
    }
    entries.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return entries;
  }

  /// Cek apakah episode tertentu sudah pernah di-download.
  DownloadEntry? get(int animeId, String episodeId) {
    final raw = _box.get('$animeId:$episodeId');
    if (raw == null) return null;
    try {
      final entry = DownloadEntry.fromJson(raw);
      // Validate file masih exist (kalau user manually delete via file manager).
      if (!File(entry.localPath).existsSync()) {
        _box.delete(entry.hiveKey);
        return null;
      }
      return entry;
    } catch (_) {
      return null;
    }
  }

  /// Hapus file + entry. Idempotent (no-op kalau tidak ada).
  Future<void> delete(int animeId, String episodeId) async {
    final entry = get(animeId, episodeId);
    if (entry == null) return;
    try {
      final f = File(entry.localPath);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      debugPrint('Delete file error: $e');
    }
    await _box.delete(entry.hiveKey);
  }
}

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  // Pakai Dio fresh tanpa cache interceptor — download butuh raw bytes.
  return DownloadRepository(Dio());
});

/// Stream provider untuk list semua downloads.
///
/// **Important:** Emit value awal langsung saat subscribe, lalu re-emit
/// setiap Hive box berubah. Kalau cuma `box.watch().map(...)`, stream tidak
/// emit apa-apa sampai ada CHANGE — UI stuck di loading state walaupun
/// sebenarnya ada data. Pakai `Stream.multi` untuk control emit pertama.
final downloadsListProvider = StreamProvider<List<DownloadEntry>>((ref) {
  final repo = ref.watch(downloadRepositoryProvider);
  final box = Hive.box<Map<dynamic, dynamic>>(HiveBoxes.downloads);
  return Stream<List<DownloadEntry>>.multi((controller) {
    // Emit initial state segera (sync dari Hive — fast).
    controller.add(repo.getAll());
    // Subscribe ke box changes untuk update real-time.
    final sub = box.watch().listen((_) {
      if (!controller.isClosed) controller.add(repo.getAll());
    });
    controller.onCancel = () => sub.cancel();
  });
});

/// Helper provider — cek apakah episode tertentu sudah ada offline.
final downloadEntryProvider =
    Provider.family<DownloadEntry?, ({int animeId, String episodeId})>((
      ref,
      args,
    ) {
      // Watch Hive box untuk re-emit kalau ada perubahan.
      ref.watch(downloadsListProvider);
      return ref
          .read(downloadRepositoryProvider)
          .get(args.animeId, args.episodeId);
    });
