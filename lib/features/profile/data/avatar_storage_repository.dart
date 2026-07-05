import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

/// Repository untuk upload foto avatar ke Supabase Storage.
///
/// Bucket: `avatars` (public-read, user-write only di folder mereka sendiri).
/// Lihat `sql/avatars_bucket.sql` untuk schema + RLS.
///
/// Path convention: `{userId}/{timestamp}.jpg`.
class AvatarStorageRepository {
  static const _bucketName = 'avatars';

  /// Upload bytes ke Supabase Storage, return public URL.
  ///
  /// Throw [StateError] kalau Supabase belum di-configure atau user belum
  /// login. Throw [Exception] kalau upload gagal (RLS deny, network, dll).
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    if (!Env.isSupabaseConfigured) {
      throw StateError('Supabase belum di-konfigurasi');
    }

    final client = Supabase.instance.client;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/$timestamp.$extension';

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

    // Get public URL — bucket sudah public:true, jadi link langsung accessible.
    final publicUrl = client.storage.from(_bucketName).getPublicUrl(path);
    debugPrint('Avatar uploaded: $publicUrl');
    return publicUrl;
  }

  /// Upload dari File (non-web platforms).
  Future<String> uploadAvatarFromFile({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    return uploadAvatar(
      userId: userId,
      bytes: bytes,
      extension: ext == 'png' ? 'png' : 'jpg',
    );
  }
}

final avatarStorageRepositoryProvider = Provider<AvatarStorageRepository>(
  (ref) => AvatarStorageRepository(),
);
