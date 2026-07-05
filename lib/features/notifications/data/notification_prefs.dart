import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/storage/hive_init.dart';

/// Preferensi notifikasi user — disimpan di Hive box `settings`.
///
/// Saat ini cuma local toggle (FCM belum di-integrate). Saat FCM aktif,
/// nilai-nilai ini dipakai untuk subscribe/unsubscribe ke topic Firebase.
///
/// Default semua ON saat first launch.
class NotificationPrefs {
  const NotificationPrefs({
    this.newEpisode = true,
    this.watchPartyInvite = true,
    this.chatMention = true,
    this.weeklyDigest = false,
    this.appUpdate = true,
  });

  /// Notif saat anime di Favorit punya episode baru airing.
  final bool newEpisode;

  /// Notif saat di-invite ke watch party oleh teman.
  final bool watchPartyInvite;

  /// Notif saat di-mention di chat watch party aktif.
  final bool chatMention;

  /// Email weekly recap aktivitas tonton.
  final bool weeklyDigest;

  /// Notif saat update aplikasi tersedia.
  final bool appUpdate;

  int get activeCount =>
      (newEpisode ? 1 : 0) +
      (watchPartyInvite ? 1 : 0) +
      (chatMention ? 1 : 0) +
      (weeklyDigest ? 1 : 0) +
      (appUpdate ? 1 : 0);

  NotificationPrefs copyWith({
    bool? newEpisode,
    bool? watchPartyInvite,
    bool? chatMention,
    bool? weeklyDigest,
    bool? appUpdate,
  }) {
    return NotificationPrefs(
      newEpisode: newEpisode ?? this.newEpisode,
      watchPartyInvite: watchPartyInvite ?? this.watchPartyInvite,
      chatMention: chatMention ?? this.chatMention,
      weeklyDigest: weeklyDigest ?? this.weeklyDigest,
      appUpdate: appUpdate ?? this.appUpdate,
    );
  }
}

class NotificationPrefsNotifier extends StateNotifier<NotificationPrefs> {
  NotificationPrefsNotifier(this._box) : super(_load(_box));

  final Box<dynamic> _box;

  static const _keyNewEpisode = 'notif_new_episode';
  static const _keyWatchPartyInvite = 'notif_watch_party_invite';
  static const _keyChatMention = 'notif_chat_mention';
  static const _keyWeeklyDigest = 'notif_weekly_digest';
  static const _keyAppUpdate = 'notif_app_update';

  static NotificationPrefs _load(Box<dynamic> box) {
    return NotificationPrefs(
      newEpisode: box.get(_keyNewEpisode, defaultValue: true) as bool,
      watchPartyInvite:
          box.get(_keyWatchPartyInvite, defaultValue: true) as bool,
      chatMention: box.get(_keyChatMention, defaultValue: true) as bool,
      weeklyDigest: box.get(_keyWeeklyDigest, defaultValue: false) as bool,
      appUpdate: box.get(_keyAppUpdate, defaultValue: true) as bool,
    );
  }

  Future<void> setNewEpisode(bool v) async {
    state = state.copyWith(newEpisode: v);
    await _box.put(_keyNewEpisode, v);
  }

  Future<void> setWatchPartyInvite(bool v) async {
    state = state.copyWith(watchPartyInvite: v);
    await _box.put(_keyWatchPartyInvite, v);
  }

  Future<void> setChatMention(bool v) async {
    state = state.copyWith(chatMention: v);
    await _box.put(_keyChatMention, v);
  }

  Future<void> setWeeklyDigest(bool v) async {
    state = state.copyWith(weeklyDigest: v);
    await _box.put(_keyWeeklyDigest, v);
  }

  Future<void> setAppUpdate(bool v) async {
    state = state.copyWith(appUpdate: v);
    await _box.put(_keyAppUpdate, v);
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, NotificationPrefs>((ref) {
      final box = Hive.box<dynamic>(HiveBoxes.settings);
      return NotificationPrefsNotifier(box);
    });
