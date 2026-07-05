import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Service notifikasi **lokal** untuk "episode baru tayang".
///
/// Tanpa server/push — tiap anime yang dilacak dijadwalkan satu notifikasi di
/// waktu `airingAt`-nya (`zonedSchedule`, mode inexact → tanpa izin exact-alarm).
/// id notifikasi = `animeId` (1 per anime; reschedule = cancelAll lalu jadwalkan
/// ulang). String (judul/isi) di-inject caller supaya tetap terlokalisasi.
class EpisodeNotificationService {
  EpisodeNotificationService._();
  static final EpisodeNotificationService instance =
      EpisodeNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Dipanggil saat user tap notifikasi (membawa animeId) — di-set oleh app
  /// untuk navigasi ke Detail.
  void Function(int animeId)? onSelectAnime;

  static const _channelId = 'episode_airing';
  static const _channelName = 'Episode Baru';
  static const _channelDesc = 'Notifikasi saat episode anime di list-mu tayang';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        final id = payload == null ? null : int.tryParse(payload);
        if (id != null) onSelectAnime?.call(id);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
          ),
        );
    _ready = true;
  }

  /// Minta izin POST_NOTIFICATIONS (Android 13+). Return true kalau diizinkan
  /// (atau OS lama yang tak butuh izin).
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return (await android?.requestNotificationsPermission()) ?? true;
  }

  /// Jadwalkan notifikasi 1 anime di waktu [airingAtUtc]. Skip kalau sudah lewat.
  Future<void> scheduleEpisode({
    required int animeId,
    required DateTime airingAtUtc,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    final when = tz.TZDateTime.from(airingAtUtc.toUtc(), tz.UTC);
    if (!when.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    await _plugin.zonedSchedule(
      animeId,
      title,
      body,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: animeId.toString(),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Debug: tampilkan notif uji [delay] dari sekarang (verifikasi tray + tap).
  Future<void> scheduleTest(Duration delay) async {
    if (!_ready) return;
    if (!kDebugMode) return;
    await _plugin.zonedSchedule(
      999999,
      'VibeNime',
      'Test notifikasi episode',
      tz.TZDateTime.now(tz.UTC).add(delay),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
