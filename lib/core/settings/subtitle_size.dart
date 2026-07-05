/// Preferensi ukuran font subtitle di player (untuk source soft-sub seperti
/// Miruro/English). Source hardsub (Sanka) tak terpengaruh — subtitle sudah
/// menyatu di video.
enum SubtitleSize {
  small(14),
  medium(18),
  large(24);

  const SubtitleSize(this.fontSize);

  /// Ukuran font (px) yang diteruskan ke `BetterPlayerSubtitlesConfiguration`.
  final double fontSize;

  String get storageKey => name;

  static SubtitleSize fromStorage(String? raw) => switch (raw) {
    'small' => SubtitleSize.small,
    'large' => SubtitleSize.large,
    _ => SubtitleSize.medium,
  };
}
