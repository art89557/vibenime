import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  HiveBoxes._();

  /// Box untuk history menonton.
  /// Key: `"${animeId}:${episodeId}"`
  /// Value: Map (lihat HistoryEntry.toJson)
  static const String history = 'history';
}

Future<void> initHive() async {
  await Hive.initFlutter();
  await Hive.openBox<Map<dynamic, dynamic>>(HiveBoxes.history);
}
