import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  static int get anilistClientId =>
      int.tryParse(dotenv.maybeGet('ANILIST_CLIENT_ID') ?? '0') ?? 0;

  /// Sample HLS URL untuk video player.
  /// Lihat keputusan teknis di PRD.md §6.2 — VibeNime tidak pakai scraper
  /// karena seri DMCA takedown 2026 (Consumet, aniwatch-api).
  static String get sampleStreamUrl =>
      dotenv.maybeGet('SAMPLE_STREAM_URL') ??
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  static const String anilistGraphqlEndpoint = 'https://graphql.anilist.co';
  static const String anilistAuthorizeUrl =
      'https://anilist.co/api/v2/oauth/authorize';
  static const String oauthRedirectScheme = 'vibenime';
  static const String oauthRedirectUrl = 'vibenime://auth-callback';
}
