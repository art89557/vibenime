/// Preferensi bahasa judul anime yang ditampilkan (seperti setting Title
/// Language di AniList). Hanya Romaji & English (sesuai permintaan).
enum TitleLanguage {
  romaji,
  english;

  String get storageKey => name;

  static TitleLanguage fromStorage(String? raw) => switch (raw) {
    'english' => TitleLanguage.english,
    _ => TitleLanguage.romaji,
  };
}

/// Holder global preferensi judul — di-sync dari `AppSettings` saat startup &
/// tiap perubahan. Dipakai oleh `Anime.displayTitle` supaya widget tak perlu
/// meneruskan preferensi lewat constructor (pola sama dgn
/// `AppAnimations.reduceAnimationsOverride`).
///
/// Catatan: ini hanya memengaruhi STRING yang ditampilkan. Karena bukan
/// Listenable, layar yang sudah ter-render perlu rebuild (perubahan setting
/// memicu rebuild via `appSettingsProvider`) agar judul ikut berganti.
class TitlePref {
  TitlePref._();

  static TitleLanguage current = TitleLanguage.romaji;
}
