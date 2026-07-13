/// Preferensi bahasa subtitle untuk player — menentukan source mana yang jadi
/// **utama** (auto-play index 0): sub Indonesia (Sanka/Samehadaku/Otakudesu)
/// atau English (Miruro). User tetap bisa override per-tontonan lewat source
/// picker; setting ini hanya menentukan default-nya.
enum SubtitleLanguage {
  indonesian,
  english;

  String get storageKey => name;

  // Default = English → **Miruro jadi source utama** (M3U8 langsung, lebih
  // andal dari scraper Indo). User bisa ganti ke Indonesia di Settings.
  static SubtitleLanguage fromStorage(String? raw) => switch (raw) {
    'indonesian' => SubtitleLanguage.indonesian,
    _ => SubtitleLanguage.english,
  };
}

/// Holder global preferensi subtitle — di-sync dari `AppSettings` saat startup
/// & tiap perubahan. Dipakai `CompositeStreamingRepository` (bukan widget) untuk
/// mengurutkan source tanpa meneruskan preferensi lewat constructor (pola sama
/// dgn `TitlePref.current`).
class SubtitlePref {
  SubtitlePref._();

  static SubtitleLanguage current = SubtitleLanguage.english;
}
