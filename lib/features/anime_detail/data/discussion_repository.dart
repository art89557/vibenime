import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import 'discussion.dart';

/// Repository untuk Diskusi anime — wrap Supabase tabel `anime_discussions`.
///
/// Pattern sama dengan WatchPartyRepository: stream untuk real-time list,
/// post via INSERT.
class DiscussionRepository {
  static const String _table = 'anime_discussions';

  /// Stream daftar diskusi untuk anime tertentu (live update via Realtime CDC).
  /// Order: terbaru di atas (descending by created_at).
  Stream<List<Discussion>> watchDiscussions(int animeId) {
    if (!Env.isSupabaseConfigured) {
      return Stream.value(const []);
    }
    return Supabase.instance.client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('anime_id', animeId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .cast<Map<String, dynamic>>()
              .map(Discussion.fromJson)
              .toList(),
        );
  }

  /// Post diskusi baru. Throw `StateError` kalau user belum login Supabase.
  Future<void> postDiscussion({
    required int animeId,
    required String username,
    required String content,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Login Supabase dulu untuk diskusi.');
    }
    await Supabase.instance.client.from(_table).insert({
      'anime_id': animeId,
      'user_id': user.id,
      'username': username,
      'content': content,
    });
  }

  /// Hapus diskusi (RLS pastikan hanya pemilik yang bisa).
  Future<void> deleteDiscussion(String discussionId) async {
    try {
      await Supabase.instance.client
          .from(_table)
          .delete()
          .eq('id', discussionId);
    } catch (e) {
      debugPrint('deleteDiscussion error: $e');
      rethrow;
    }
  }
}

final discussionRepositoryProvider = Provider<DiscussionRepository>(
  (ref) => DiscussionRepository(),
);

/// Stream provider — auto re-emit saat ada post baru.
final discussionsStreamProvider = StreamProvider.family
    .autoDispose<List<Discussion>, int>((ref, animeId) {
      final repo = ref.watch(discussionRepositoryProvider);
      return repo.watchDiscussions(animeId);
    });
