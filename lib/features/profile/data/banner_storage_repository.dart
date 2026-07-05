import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

/// Repository untuk upload banner image ke Supabase Storage.
///
/// Bucket: `banners` (public-read, user-write only di folder mereka sendiri).
/// Lihat `sql/banners_bucket.sql` untuk schema + RLS.
///
/// Path: `{userId}/banner-{timestamp}.jpg`.
class BannerStorageRepository {
  static const _bucketName = 'banners';

  Future<String> uploadBanner({
    required String userId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase belum di-konfigurasi');
    }

    final client = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/banner-$timestamp.$extension';

    await client.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: 'image/$extension',
          ),
        );

    final publicUrl = client.storage.from(_bucketName).getPublicUrl(path);
    debugPrint('Banner uploaded: $publicUrl');
    return publicUrl;
  }
}

final bannerStorageRepositoryProvider = Provider<BannerStorageRepository>(
  (ref) => BannerStorageRepository(),
);
