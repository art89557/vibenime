/// Enum untuk tipe sumber video di `video_sources.source_type` Supabase.
///
/// Memberikan **type-safety** dan **single source of truth** untuk string
/// literal yang sebelumnya hardcoded di banyak tempat (admin form,
/// streaming_repository, dll).
///
/// Setiap value match `CHECK constraint` di SQL schema (`init.sql`):
/// ```sql
/// source_type text default 'archive_org' check (
///   source_type in ('archive_org', 'cloudflare_r2', 'mux', 'youtube', 'manual')
/// )
/// ```
///
/// Penggunaan:
/// ```dart
/// final type = SourceType.fromValue('youtube');  // SourceType.youtube
/// final str = SourceType.archiveOrg.value;       // 'archive_org'
/// final all = SourceType.values;                  // semua untuk dropdown
/// ```
enum SourceType {
  /// Internet Archive (archive.org) — direct .mp4 link untuk anime classic
  /// public domain. Reliable & legal.
  archiveOrg('archive_org', 'Internet Archive', 'archive.org/download/...'),

  /// Cloudflare R2 storage — self-hosted .mp4. Butuh setup R2 bucket.
  cloudflareR2('cloudflare_r2', 'Cloudflare R2', 'pub-xxx.r2.dev/...'),

  /// Mux test stream — sample HLS multi-bitrate (Big Buck Bunny).
  /// Dipakai untuk fallback saat tidak ada source lain.
  mux('mux', 'Mux Test Stream', 'test-streams.mux.dev/...'),

  /// YouTube full episode — channel resmi seperti Muse Asia, Ani-One Asia.
  /// Player render via `YoutubePlayer`, bukan BetterPlayer.
  youtube('youtube', 'YouTube (Muse Asia, dll)', 'youtube.com/watch?v=...'),

  /// Generic/manual URL — direct .mp4 dari sumber lain (Backblaze B2,
  /// Google Drive direct download, dll).
  manual('manual', 'Manual / Other', 'https://...');

  const SourceType(this.value, this.label, this.placeholder);

  /// String value yang disimpan di database.
  final String value;

  /// Human-readable label untuk UI dropdown.
  final String label;

  /// Placeholder URL untuk hint text di form input.
  final String placeholder;

  /// Parse dari string database. Return `manual` kalau value tidak dikenal.
  static SourceType fromValue(String value) {
    return SourceType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => SourceType.manual,
    );
  }

  /// True kalau source ini di-render via `YoutubePlayer` (bukan BetterPlayer).
  bool get isYoutube => this == SourceType.youtube;
}
