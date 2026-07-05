import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

enum ActivityEventType {
  watchedEpisode('watched_episode', 'menonton'),
  addedToList('added_to_list', 'menambah ke list'),
  completedAnime('completed_anime', 'menyelesaikan'),
  favorited('favorited', 'memfavoritkan');

  const ActivityEventType(this.code, this.verb);
  final String code;
  final String verb;

  static ActivityEventType fromCode(String? code) {
    for (final t in ActivityEventType.values) {
      if (t.code == code) return t;
    }
    return ActivityEventType.watchedEpisode;
  }
}

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.animeId,
    required this.animeTitle,
    this.animeCover,
    this.metadata,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final ActivityEventType type;
  final int animeId;
  final String animeTitle;
  final String? animeCover;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: ActivityEventType.fromCode(json['type'] as String?),
      animeId: (json['anime_id'] as num).toInt(),
      animeTitle: json['anime_title'] as String,
      animeCover: json['anime_cover'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Repository untuk log + fetch activity events.
class ActivityRepository {
  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  /// Log event aktivitas + auto-trigger XP reward + badge check.
  /// Silent fail kalau gagal (best-effort).
  ///
  /// XP rules (mirror SQL gamification.sql):
  /// - watched_episode: +10 XP
  /// - added_to_list: +5 XP
  /// - completed_anime: +100 XP
  /// - favorited: +5 XP
  Future<void> logEvent({
    required ActivityEventType type,
    required int animeId,
    required String animeTitle,
    String? animeCover,
    Map<String, dynamic>? metadata,
  }) async {
    final myId = _myId;
    if (myId == null || !Env.isSupabaseConfigured) return;
    try {
      await Supabase.instance.client.from('activity_events').insert({
        'user_id': myId,
        'type': type.code,
        'anime_id': animeId,
        'anime_title': animeTitle,
        'anime_cover': ?animeCover,
        'metadata': ?metadata,
      });
      // Auto-XP via add_xp RPC (silent fail kalau gamification SQL belum di-jalankan)
      final xpAmount = switch (type) {
        ActivityEventType.watchedEpisode => 10,
        ActivityEventType.addedToList => 5,
        ActivityEventType.completedAnime => 100,
        ActivityEventType.favorited => 5,
      };
      try {
        await Supabase.instance.client.rpc(
          'add_xp',
          params: {'amount': xpAmount},
        );
        await Supabase.instance.client.rpc('check_and_award_badges');
      } catch (xpErr) {
        debugPrint('XP/badge skipped: $xpErr');
      }
    } catch (e) {
      debugPrint('logEvent failed (silent): $e');
    }
  }

  /// Fetch feed events dari friends + self (RLS handle authorization).
  /// Limit 50 untuk performance.
  Future<List<ActivityEvent>> getFeed({int limit = 50}) async {
    if (!Env.isSupabaseConfigured) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('activity_events')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(ActivityEvent.fromJson)
          .toList();
    } catch (e) {
      debugPrint('getFeed failed: $e');
      return const [];
    }
  }
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(),
);

final activityFeedProvider = FutureProvider.autoDispose<List<ActivityEvent>>((
  ref,
) async {
  return ref.watch(activityRepositoryProvider).getFeed();
});
