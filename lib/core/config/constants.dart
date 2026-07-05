/// Konstanta global VibeNime — magic numbers, durations, default values.
///
/// **Kenapa file ini ada?**
/// Sebelumnya banyak nilai seperti `Duration(seconds: 5)`, `350` (debounce),
/// `30 * 60` (cache 30 menit), dll. tersebar di banyak file. Konsolidasikan
/// di sini supaya:
/// 1. Mudah di-tweak tanpa cari-cari
/// 2. Mudah di-test (override di test setup)
/// 3. Self-documenting (nama variable > magic number)
///
/// Untuk konstanta runtime yang bisa berubah berdasar env, lihat `Env` di
/// `core/config/env.dart`.
library;

/// Duration & timing-related constants.
class TimingConstants {
  TimingConstants._();

  /// Debounce search input — ms sebelum trigger query API.
  ///
  /// Trade-off: lebih kecil = lebih responsive tapi lebih banyak request.
  /// 350ms adalah sweet spot untuk pengetikan normal.
  static const Duration searchDebounce = Duration(milliseconds: 350);

  /// Interval simpan posisi tonton ke history (Hive).
  ///
  /// Dipakai di `PlayerScreen` listener — save tiap 5 detik supaya:
  /// - Tidak spam disk write
  /// - Tetap presisi cukup untuk resume feature
  static const Duration playerProgressSaveInterval = Duration(seconds: 5);

  /// Cache lifetime untuk Discover sections (Trending, Popular, dll).
  ///
  /// Section ini jarang berubah (rate-limit AniList 90/min), jadi cache 30 menit
  /// cukup mengurangi load tanpa bikin data terlihat stale.
  static const Duration discoverCacheTtl = Duration(minutes: 30);

  /// Cache lifetime untuk anime detail (sinopsis, episode count, dll).
  ///
  /// Anime detail rarely changes — cache 1 jam aman.
  static const Duration animeDetailCacheTtl = Duration(hours: 1);

  /// Splash screen minimum display time.
  ///
  /// User butuh ~1.2 detik untuk register branding sebelum pindah layar.
  /// Lebih cepat dari ini = jarring; lebih lama = annoying.
  static const Duration splashMinDisplay = Duration(milliseconds: 1200);

  /// HTTP request timeout untuk API call AniList & Supabase.
  ///
  /// Cukup panjang untuk koneksi lambat tapi tidak nyiksa user.
  static const Duration httpTimeout = Duration(seconds: 30);

  /// Network simulation delay di sample repository (untuk demo realism).
  static const Duration sampleNetworkDelay = Duration(milliseconds: 200);

  /// Timeout per source streaming (Miruro/Otakudesu/Samehadaku/catalog) saat
  /// `fetchPayloads`. Source di-fetch paralel; satu source lambat/hang tidak
  /// boleh menunda playback dari source lain yang cepat. Lebih pendek dari
  /// [httpTimeout] karena ini sekadar "siapa duluan" antar mirror.
  static const Duration sourceFetchTimeout = Duration(seconds: 12);
}

/// Pagination & list-size constants.
class PaginationConstants {
  PaginationConstants._();

  /// Jumlah item per page untuk Discover sections.
  ///
  /// 12 cukup untuk fill 1-2 row di horizontal scroll, tidak overload memori.
  static const int discoverPerPage = 12;

  /// Jumlah hasil search per query.
  ///
  /// 25 = 5 row × 5 col grid. Cukup tanpa pagination kompleks untuk MVP.
  static const int searchPerPage = 25;

  /// Limit recent watched untuk "Continue Watching" section.
  static const int recentWatchedLimit = 10;

  /// Max source fallback yang dicoba player saat error.
  ///
  /// Lebih dari ini biasanya futile — kalau 3 source semua fail,
  /// kemungkinan masalah jaringan user.
  static const int maxSourceFallback = 3;

  /// Default priority kalau user tidak set di admin form.
  ///
  /// Pakai 100 supaya ada ruang di atas (priority 1-99) untuk source
  /// premium yang harus diprioritaskan.
  static const int defaultSourcePriority = 100;
}

/// Episode-related defaults.
class EpisodeConstants {
  EpisodeConstants._();

  /// Default jumlah episode kalau AniList tidak punya data
  /// (mis. anime ongoing yang `episodes: null`).
  static const int fallbackEpisodeCount = 12;

  /// Average duration anime episode dalam menit (untuk hitungan stat).
  ///
  /// Dipakai di profile screen: `total_jam = total_ep * 24 / 60`.
  /// Lebih akurat kalau pakai `Anime.duration` real, tapi kalau null
  /// fallback ke 24 menit (TV anime standard).
  static const int defaultEpisodeDurationMinutes = 24;

  /// Threshold untuk consider episode "selesai" — kalau progress >= ini.
  ///
  /// 0.9 = 90% (skip credit roll).
  static const double finishedThresholdFraction = 0.9;
}

/// External URL constants.
class UrlConstants {
  UrlConstants._();

  /// Channel YouTube Muse Indonesia (anime full episode legal SE Asia).
  static const String museAsiaChannel =
      'https://www.youtube.com/@MuseIndonesia/videos';

  /// Channel YouTube Ani-One Asia.
  static const String aniOneChannel = 'https://www.youtube.com/@Ani-OneAsia';

  /// Base URL AniList untuk lookup anime by ID (untuk admin "Cek di AniList").
  static const String anilistAnimeBase = 'https://anilist.co/anime/';

  /// Default subtitle URL untuk fallback Mux sample stream.
  static const String muxSampleSubtitleUrl =
      'https://test-streams.mux.dev/captions/captions_en.vtt';
}
