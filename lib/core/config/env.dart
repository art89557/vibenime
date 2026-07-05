import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  /// Sample HLS URL untuk fallback player.
  static String get sampleStreamUrl =>
      dotenv.maybeGet('SAMPLE_STREAM_URL') ??
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  /// Supabase project URL. Empty kalau Supabase belum di-setup.
  static String get supabaseUrl => dotenv.maybeGet('SUPABASE_URL') ?? '';

  /// Supabase anon public key. Empty kalau belum di-setup.
  static String get supabaseAnonKey =>
      dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  /// True kalau Supabase ter-konfigurasi dengan benar.
  /// Repository bisa cek ini dulu sebelum query Supabase.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// AniList GraphQL endpoint — dipakai sebagai PUBLIC API untuk katalog
  /// (trending, popular, search, detail, schedule). Tidak butuh auth
  /// header sejak fitur "Sync dengan AniList" dihilangkan.
  static const String anilistGraphqlEndpoint = 'https://graphql.anilist.co';

  /// Self-hosted Consumet API base URL (untuk source Indonesia: Otakudesu,
  /// Kuramanime, Samehadaku). Empty kalau belum di-deploy — Flutter akan
  /// fallback ke public Consumet mirror (gogoanime) atau Mux sample.
  ///
  /// Setup: fork github.com/consumet/api-anime, tambah 3 Indo modules
  /// (port dari Aniyomi extensions), deploy ke Vercel/Railway, set URL
  /// di sini lewat `.env`.
  static String get consumetApiUrl => dotenv.maybeGet('CONSUMET_API_URL') ?? '';

  /// True kalau backend Consumet self-hosted sudah di-set.
  static bool get isConsumetConfigured => consumetApiUrl.isNotEmpty;

  /// Self-hosted **wajik-anime-api** base URL — sumber streaming dinamis utama
  /// (pengganti Consumet yang sudah tidak reliable).
  ///
  /// Repo: github.com/wajik45/wajik-anime-api (scrape Otakudesu/Samehadaku/
  /// Kuramanime, sub Indonesia). Deploy ke Vercel, lalu set `ANIME_API_URL`
  /// di `.env` (base URL TANPA trailing slash, mis.
  /// `https://my-anime-api.vercel.app`). Client otomatis tambah path
  /// `/{source}/...` (mis. `/otakudesu/search`).
  ///
  /// Kosong = pakai public demo `wajik-anime-api.vercel.app` (sering down) lalu
  /// fallback Mux sample. **Sangat dianjurkan deploy sendiri.**
  static String get animeApiUrl => dotenv.maybeGet('ANIME_API_URL') ?? '';

  /// True kalau backend wajik-anime-api self-hosted sudah di-set.
  static bool get isAnimeApiConfigured => animeApiUrl.isNotEmpty;

  /// Self-hosted **Miruro-API** base URL — sumber streaming M3U8 langsung
  /// (github.com/walterwhite-69/Miruro-API). Pakai AniList ID, balas HLS +
  /// subtitle + intro/outro. Sub EN. Deploy Python/FastAPI (Railway/Render/
  /// Vercel-mangum), set `MIRURO_API_URL` di `.env` (tanpa trailing slash).
  ///
  /// Kosong = source Miruro di-skip (tak ada public demo).
  static String get miruroApiUrl => dotenv.maybeGet('MIRURO_API_URL') ?? '';

  /// True kalau backend Miruro-API self-hosted sudah di-set.
  static bool get isMiruroConfigured => miruroApiUrl.isNotEmpty;

  /// (Opsional) API key Miruro-API — kalau deploy di-lock pakai env `API_KEY`.
  /// Dikirim sebagai header `x-api-key`. Kosong = andalkan Referer (deploy
  /// dengan `ALLOWED_ORIGINS` kosong menerima Referer apa pun).
  static String get miruroApiKey => dotenv.maybeGet('MIRURO_API_KEY') ?? '';

  /// **Sankanime** (sub Indonesia) — template URL halaman tonton yang
  /// di-embed lewat WebView (lihat `_WebViewPlayerView`). Sankanime adalah SPA
  /// di-proteksi Cloudflare tanpa API publik, jadi integrasi pakai embed URL
  /// yang dibangun dari template ini (bukan scraping dari app).
  ///
  /// Placeholder yang didukung:
  ///   `{slug}`  → judul anime jadi kebab-case (mis. `one-piece`)
  ///   `{title}` → judul anime URL-encoded
  ///   `{ep}`    → nomor episode
  ///
  /// Contoh: `https://sankanime.web.id/{slug}-episode-{ep}-sub-indo`
  /// Kosong = source Sankanime di-skip (no-op, tanpa regresi).
  static String get sankanimeEmbedTemplate =>
      dotenv.maybeGet('SANKANIME_EMBED_TEMPLATE') ?? '';

  /// True kalau template embed Sankanime sudah di-set.
  static bool get isSankanimeConfigured => sankanimeEmbedTemplate.isNotEmpty;
}
