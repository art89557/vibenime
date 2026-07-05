/// Preferensi bahasa subtitle untuk player — menentukan source mana yang jadi
/// **utama** (auto-play index 0): sub Indonesia (Sanka/Samehadaku/Otakudesu)
/// atau English (Miruro). User tetap bisa override per-tontonan lewat source
/// picker; setting ini hanya menentukan default-nya.
enum SubtitleLanguage {
  indonesian,
  english;

  String get storageKey => name;

  static SubtitleLanguage fromStorage(String? raw) => switch (raw) {
    'english' => SubtitleLanguage.english,
    _ => SubtitleLanguage.indonesian,
  };
}

/// Holder global preferensi subtitle — di-sync dari `AppSettings` saat startup
/// & tiap perubahan. Dipakai `CompositeStreamingRepository` (bukan widget) untuk
/// mengurutkan source tanpa meneruskan preferensi lewat constructor (pola sama
/// dgn `TitlePref.current`).
class SubtitlePref {
  SubtitlePref._();

  static SubtitleLanguage current = SubtitleLanguage.indonesian;
}
