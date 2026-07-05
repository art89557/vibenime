import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/constants.dart';
import '../../../core/config/env.dart';
import '../../../core/utils/source_type.dart';

/// Satu entry video source dari tabel `video_sources` di Supabase.
///
/// Multiple instances bisa exist untuk satu pasangan
/// `(anilistId, episodeNumber)` — di-rank lewat field [priority] (lower =
/// higher priority).
///
/// ```dart
/// final src = VideoSource.fromJson(supabaseRow);
/// player.play(src.videoUrl);
/// ```
class VideoSource {
  /// Construct manual (jarang dipanggil langsung — biasanya pakai factory).
  const VideoSource({
    required this.id,
    required this.anilistId,
    required this.episodeNumber,
    required this.videoUrl,
    required this.sourceType,
    this.subtitleUrl,
    this.language = 'en',
    this.quality = '480p',
    this.priority = PaginationConstants.defaultSourcePriority,
    this.notes,
  });

  /// Primary key UUID dari Supabase.
  final String id;

  /// AniList anime ID — link ke metadata di `Anime.id`.
  final int anilistId;

  /// Nomor episode (1-based).
  final int episodeNumber;

  /// URL video — bisa `.mp4`, `.m3u8`, atau YouTube watch URL tergantung
  /// [sourceType].
  final String videoUrl;

  /// URL .vtt subtitle (optional). YouTube source biasanya null karena
  /// pakai CC native.
  final String? subtitleUrl;

  /// ISO 639-1 language code subtitle (`en`, `id`, `ja`).
  final String language;

  /// Label kualitas (`240p` - `1080p`, `auto`).
  final String quality;

  /// Tipe sumber — menentukan player mana yang dipakai (BetterPlayer vs
  /// YoutubePlayer). Lihat [SourceType].
  final String sourceType;

  /// Priority untuk fallback chain — **lower = higher priority**.
  /// Default 100. Pakai 50 untuk premium source, 200 untuk fallback terakhir.
  final int priority;

  /// Catatan admin (mis. "Spy x Family EP 1 — Muse Asia").
  final String? notes;

  /// Wrapper [SourceType] enum dari [sourceType] string (type-safe).
  SourceType get sourceTypeEnum => SourceType.fromValue(sourceType);

  /// True kalau source ini di-render via YouTubePlayer (bukan BetterPlayer).
  bool get isYoutubeSource => sourceTypeEnum.isYoutube;

  /// Build dari row Supabase.
  factory VideoSource.fromJson(Map<String, dynamic> json) {
    return VideoSource(
      id: json['id'] as String,
      anilistId: (json['anilist_id'] as num).toInt(),
      episodeNumber: (json['episode_number'] as num).toInt(),
      videoUrl: json['video_url'] as String,
      subtitleUrl: json['subtitle_url'] as String?,
      language: (json['language'] as String?) ?? 'en',
      quality: (json['quality'] as String?) ?? '480p',
      sourceType: (json['source_type'] as String?) ?? 'manual',
      priority:
          (json['priority'] as num?)?.toInt() ??
          PaginationConstants.defaultSourcePriority,
      notes: json['notes'] as String?,
    );
  }

  /// Map untuk INSERT/UPDATE — exclude `id` & timestamps (auto-generated).
  Map<String, dynamic> toInsertJson() {
    return {
      'anilist_id': anilistId,
      'episode_number': episodeNumber,
      'video_url': videoUrl,
      'subtitle_url': subtitleUrl,
      'language': language,
      'quality': quality,
      'source_type': sourceType,
      'priority': priority,
      'notes': notes,
    };
  }

  /// Immutable copy dengan field tertentu diubah. Pattern standard Dart.
  VideoSource copyWith({
    String? id,
    int? anilistId,
    int? episodeNumber,
    String? videoUrl,
    String? subtitleUrl,
    String? language,
    String? quality,
    String? sourceType,
    int? priority,
    String? notes,
  }) {
    return VideoSource(
      id: id ?? this.id,
      anilistId: anilistId ?? this.anilistId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      videoUrl: videoUrl ?? this.videoUrl,
      subtitleUrl: subtitleUrl ?? this.subtitleUrl,
      language: language ?? this.language,
      quality: quality ?? this.quality,
      sourceType: sourceType ?? this.sourceType,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
    );
  }
}

/// Repository untuk video catalog di Supabase.
///
/// Method dibagi 2 kategori:
/// - **Public read** (anon access OK): [fetchSources], [fetchSource],
///   [hasSource]
/// - **Admin write** (butuh authenticated user): [fetchAll], [insert],
///   [update], [delete]
///
/// Auto-skip kalau Supabase tidak ter-config (`.env` kosong) — return
/// empty/null. Konsumer (`StreamingRepository`) akan fallback.
///
/// ```dart
/// final repo = ref.read(videoCatalogRepositoryProvider);
/// final sources = await repo.fetchSources(
///   anilistId: 140960,
///   episodeNumber: 1,
/// );
/// // sources sorted by priority asc
/// ```
class VideoCatalogRepository {
  static const String _table = 'video_sources';

  /// Fetch SEMUA video source untuk pasangan anime+episode, **sorted by
  /// priority ascending** (lower priority number = lebih dulu dicoba).
  ///
  /// Dipakai oleh `StreamingRepository` untuk fallback chain.
  /// Return empty list kalau:
  /// - Supabase belum di-config
  /// - Tidak ada entry untuk anime+episode
  /// - Network error (caught silently, return empty)
  ///
  /// ```dart
  /// final sources = await repo.fetchSources(anilistId: 4082, episodeNumber: 1);
  /// // [VideoSource(priority: 50, ...), VideoSource(priority: 100, ...), ...]
  /// ```
  Future<List<VideoSource>> fetchSources({
    required int anilistId,
    required int episodeNumber,
  }) async {
    if (!Env.isSupabaseConfigured) return const [];

    try {
      final response = await Supabase.instance.client
          .from(_table)
          .select()
          .eq('anilist_id', anilistId)
          .eq('episode_number', episodeNumber)
          .order('priority', ascending: true)
          .limit(PaginationConstants.maxSourceFallback);

      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(VideoSource.fromJson)
          .toList();
    } catch (e) {
      debugPrint('Supabase fetchSources error: $e');
      return const [];
    }
  }

  /// Fetch source PRIMARY (priority terendah) untuk anime+episode.
  ///
  /// **Deprecated** — gunakan [fetchSources] untuk dapat full fallback chain.
  /// Method ini ada untuk backward compat.
  Future<VideoSource?> fetchSource({
    required int anilistId,
    required int episodeNumber,
  }) async {
    final sources = await fetchSources(
      anilistId: anilistId,
      episodeNumber: episodeNumber,
    );
    return sources.isEmpty ? null : sources.first;
  }

  /// Quick check apakah anime tertentu punya entry di catalog.
  /// Berguna untuk badge UI ("ada di catalog").
  Future<bool> hasSource(int anilistId) async {
    if (!Env.isSupabaseConfigured) return false;
    try {
      final response = await Supabase.instance.client
          .from(_table)
          .select('id')
          .eq('anilist_id', anilistId)
          .limit(1)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Fetch SEMUA video source di database (untuk admin panel).
  /// Sorted by `(anilist_id asc, episode_number asc, priority asc)`.
  Future<List<VideoSource>> fetchAll() async {
    if (!Env.isSupabaseConfigured) return [];

    final response = await Supabase.instance.client
        .from(_table)
        .select()
        .order('anilist_id', ascending: true)
        .order('episode_number', ascending: true)
        .order('priority', ascending: true);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(VideoSource.fromJson)
        .toList();
  }

  /// Insert video source baru. Butuh authenticated Supabase user.
  ///
  /// Throw exception kalau:
  /// - User belum login Supabase (RLS reject)
  /// - Network/database error
  ///
  /// Konsumer (`AdminFormScreen`) catch & display error.
  Future<VideoSource> insert({
    required int anilistId,
    required int episodeNumber,
    required String videoUrl,
    String? subtitleUrl,
    String language = 'en',
    String quality = '480p',
    String sourceType = 'archive_org',
    int priority = PaginationConstants.defaultSourcePriority,
    String? notes,
  }) async {
    final response = await Supabase.instance.client
        .from(_table)
        .insert({
          'anilist_id': anilistId,
          'episode_number': episodeNumber,
          'video_url': videoUrl,
          'subtitle_url': subtitleUrl,
          'language': language,
          'quality': quality,
          'source_type': sourceType,
          'priority': priority,
          'notes': notes,
        })
        .select()
        .single();

    return VideoSource.fromJson(response);
  }

  /// Bulk insert multiple sources sekaligus dalam satu round-trip.
  ///
  /// Lebih efisien dari N kali [insert] karena Supabase support
  /// batch INSERT lewat array di body request. Kalau salah satu row
  /// fail constraint, **transaction rollback** — tidak ada partial insert.
  ///
  /// Butuh authenticated Supabase user (RLS policy).
  ///
  /// ```dart
  /// final saved = await repo.insertMany([
  ///   VideoSource(...),  // ep 1
  ///   VideoSource(...),  // ep 2
  ///   VideoSource(...),  // ep 3
  /// ]);
  /// // saved.length == 3
  /// ```
  Future<List<VideoSource>> insertMany(List<VideoSource> sources) async {
    if (sources.isEmpty) return const [];

    final response = await Supabase.instance.client
        .from(_table)
        .insert(sources.map((s) => s.toInsertJson()).toList())
        .select();

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(VideoSource.fromJson)
        .toList();
  }

  /// Update video source existing. Butuh authenticated user.
  Future<VideoSource> update(VideoSource source) async {
    final response = await Supabase.instance.client
        .from(_table)
        .update(source.toInsertJson())
        .eq('id', source.id)
        .select()
        .single();
    return VideoSource.fromJson(response);
  }

  /// Hard-delete video source by id. Butuh authenticated user.
  Future<void> delete(String id) async {
    await Supabase.instance.client.from(_table).delete().eq('id', id);
  }
}

/// Riverpod provider untuk [VideoCatalogRepository] singleton.
final videoCatalogRepositoryProvider = Provider<VideoCatalogRepository>(
  (ref) => VideoCatalogRepository(),
);
