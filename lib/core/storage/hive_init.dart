import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  HiveBoxes._();

  /// Box untuk history menonton.
  /// Key: `"${animeId}:${episodeId}"`
  /// Value: Map (lihat HistoryEntry.toJson)
  static const String history = 'history';

  /// Box untuk video yang sudah di-download offline.
  /// Key: `"${animeId}:${episodeId}"`
  /// Value: Map (lihat DownloadEntry.toJson)
  static const String downloads = 'downloads';

  /// Box untuk recent search history.
  /// Key: auto-increment int, Value: query string
  /// Max 10 entries — oldest dipangkas saat insert.
  static const String searchHistory = 'search_history';

  /// Box untuk app settings (theme, language, dll).
  /// Key: string setting name, Value: dynamic.
  static const String settings = 'settings';

  /// Box untuk anime favorite (Pustaka "Rencana tonton").
  /// Key: `animeId.toString()`, Value: Map (lihat FavoriteEntry.toJson).
  /// Tidak butuh akun — pure local bookmark.
  static const String favorites = 'favorites';

  /// Cache persisten respons AniList (JSON-encoded) untuk browsing offline.
  /// Key: hash query+variables, Value: `{ "ts": int, "data": <json> }` string.
  static const String anilistCache = 'anilist_cache';
}

Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.history);
  await Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.downloads);
  await Hive.openBox<String>(HiveBoxes.searchHistory);
  await Hive.openBox<dynamic>(HiveBoxes.settings);
  await Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.favorites);
  await Hive.openBox<String>(HiveBoxes.anilistCache);
}
