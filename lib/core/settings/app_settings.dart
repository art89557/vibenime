import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../animation/animations.dart';
import '../storage/hive_init.dart';
import 'subtitle_language.dart';
import 'subtitle_size.dart';
import 'title_language.dart';

/// State user preferences yang persist di Hive box `settings`.
///
/// Saat ini menyimpan:
/// - **themeMode**: dark / light / system (default: dark)
/// - **onboardingSeen**: bool — flag first-launch onboarding (default: false)
/// - (future) language: ID / EN
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.onboardingSeen,
    this.autoNext = true,
    this.autoSkip = false,
    this.reduceAnimations = false,
    this.titleLanguage = TitleLanguage.romaji,
    this.subtitleLanguage = SubtitleLanguage.english,
    this.subtitleSize = SubtitleSize.medium,
    this.notifEpisodes = false,
  });

  final ThemeMode themeMode;
  final bool onboardingSeen;

  /// Bahasa judul anime yang ditampilkan (Romaji/English) — global.
  final TitleLanguage titleLanguage;

  /// Bahasa subtitle default player (Indonesia/English) — menentukan source
  /// utama (Sanka vs Miruro). User tetap bisa override via source picker.
  final SubtitleLanguage subtitleLanguage;

  /// Ukuran font subtitle player (Small/Medium/Large) untuk source soft-sub.
  final SubtitleSize subtitleSize;

  /// Notifikasi lokal "episode baru" untuk anime di My List (opt-in).
  final bool notifEpisodes;

  /// Otomatis lanjut ke episode berikutnya saat video selesai.
  final bool autoNext;

  /// Otomatis skip intro/outro saat masuk rentang AniSkip (tanpa tombol).
  final bool autoSkip;

  /// Kurangi animasi entrance/stagger (untuk perangkat low-end / preferensi).
  final bool reduceAnimations;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? onboardingSeen,
    bool? autoNext,
    bool? autoSkip,
    bool? reduceAnimations,
    TitleLanguage? titleLanguage,
    SubtitleLanguage? subtitleLanguage,
    SubtitleSize? subtitleSize,
    bool? notifEpisodes,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    autoNext: autoNext ?? this.autoNext,
    autoSkip: autoSkip ?? this.autoSkip,
    reduceAnimations: reduceAnimations ?? this.reduceAnimations,
    titleLanguage: titleLanguage ?? this.titleLanguage,
    subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
    subtitleSize: subtitleSize ?? this.subtitleSize,
    notifEpisodes: notifEpisodes ?? this.notifEpisodes,
  );
}

/// Notifier yang baca/tulis ke Hive box untuk persist setting antar session.
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier(this._box)
    : super(
        AppSettings(
          themeMode: _loadThemeMode(_box),
          onboardingSeen: _box.get('onboardingSeen') as bool? ?? false,
          autoNext: _box.get('autoNext') as bool? ?? true,
          autoSkip: _box.get('autoSkip') as bool? ?? false,
          reduceAnimations: _box.get('reduceAnimations') as bool? ?? false,
          titleLanguage: TitleLanguage.fromStorage(
            _box.get('title_language') as String?,
          ),
          subtitleLanguage: SubtitleLanguage.fromStorage(
            _box.get('subtitle_language') as String?,
          ),
          subtitleSize: SubtitleSize.fromStorage(
            _box.get('subtitle_size') as String?,
          ),
          notifEpisodes: _box.get('notif_episodes') as bool? ?? false,
        ),
      ) {
    // Sinkronkan override statis dari nilai tersimpan saat startup.
    AppAnimations.reduceAnimationsOverride = state.reduceAnimations;
    TitlePref.current = state.titleLanguage;
    SubtitlePref.current = state.subtitleLanguage;
  }

  final Box<dynamic> _box;

  static ThemeMode _loadThemeMode(Box<dynamic> box) {
    final raw = box.get('themeMode') as String?;
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    await _box.put('themeMode', raw);
  }

  /// Tandai onboarding sudah dilihat. Dipanggil di akhir flow onboarding,
  /// supaya next launch langsung skip ke login/home.
  Future<void> markOnboardingSeen() async {
    state = state.copyWith(onboardingSeen: true);
    await _box.put('onboardingSeen', true);
  }

  Future<void> setAutoNext(bool value) async {
    state = state.copyWith(autoNext: value);
    await _box.put('autoNext', value);
  }

  Future<void> setAutoSkip(bool value) async {
    state = state.copyWith(autoSkip: value);
    await _box.put('autoSkip', value);
  }

  Future<void> setReduceAnimations(bool value) async {
    state = state.copyWith(reduceAnimations: value);
    AppAnimations.reduceAnimationsOverride = value;
    await _box.put('reduceAnimations', value);
  }

  Future<void> setTitleLanguage(TitleLanguage value) async {
    state = state.copyWith(titleLanguage: value);
    TitlePref.current = value;
    await _box.put('title_language', value.storageKey);
  }

  Future<void> setSubtitleLanguage(SubtitleLanguage value) async {
    state = state.copyWith(subtitleLanguage: value);
    SubtitlePref.current = value;
    await _box.put('subtitle_language', value.storageKey);
  }

  Future<void> setSubtitleSize(SubtitleSize value) async {
    state = state.copyWith(subtitleSize: value);
    await _box.put('subtitle_size', value.storageKey);
  }

  Future<void> setNotifEpisodes(bool value) async {
    state = state.copyWith(notifEpisodes: value);
    await _box.put('notif_episodes', value);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      final box = Hive.box<dynamic>(HiveBoxes.settings);
      return AppSettingsNotifier(box);
    });
