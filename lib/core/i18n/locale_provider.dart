import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../storage/hive_init.dart';

/// State locale aplikasi — persisted di Hive box `settings`.
///
/// 3 mode:
/// - **system**: ikut device locale (default)
/// - **id**: paksa Bahasa Indonesia
/// - **en**: paksa English
class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._box) : super(_load(_box));

  final Box<dynamic> _box;
  static const _key = 'locale_code';

  static Locale? _load(Box<dynamic> box) {
    final raw = box.get(_key) as String?;
    if (raw == null || raw == 'system') return null; // null = follow system
    return Locale(raw);
  }

  /// `code`: 'en', 'id', atau 'system'.
  Future<void> setLocale(String code) async {
    if (code == 'system') {
      state = null;
      await _box.put(_key, 'system');
    } else {
      state = Locale(code);
      await _box.put(_key, code);
    }
  }

  /// Current code untuk UI display.
  String get currentCode {
    final s = state;
    if (s == null) return 'system';
    return s.languageCode;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  final box = Hive.box<dynamic>(HiveBoxes.settings);
  return LocaleNotifier(box);
});
