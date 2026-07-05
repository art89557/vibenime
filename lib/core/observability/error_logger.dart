import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Logger error ringan (pengganti Sentry yang dihapus karena incompat NDK).
///
/// Fungsi:
/// - Pasang handler global (`FlutterError.onError` + `PlatformDispatcher.onError`).
/// - Simpan N error terakhir di ring buffer in-memory (untuk debug screen).
/// - `debugPrint` dengan tag supaya kelihatan di console.
/// - **Kirim ke Supabase** (`crash_logs`) secara best-effort: hanya di build
///   **non-debug**, rate-limited (dedupe + cap per-sesi), fire-and-forget.
///   Guard `Env.isSupabaseConfigured`. Lihat `sql/07_crash_logs.sql`.
class ErrorLogger {
  ErrorLogger._();

  static final ErrorLogger instance = ErrorLogger._();

  static const _maxEntries = 50;
  final Queue<AppErrorEntry> _entries = Queue<AppErrorEntry>();

  /// Rate-limit pengiriman ke Supabase: maks per sesi + dedupe error identik.
  static const _maxReportsPerSession = 20;
  int _reportsSent = 0;
  final Set<int> _reportedHashes = <int>{};

  /// Snapshot error terakhir (terbaru di depan).
  List<AppErrorEntry> get recent => _entries.toList().reversed.toList();

  /// Pasang handler global. Panggil sekali di `main()` sebelum `runApp`.
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack, context: 'FlutterError');
      previous?.call(details);
    };

    // Error async di luar widget tree (mis. Future tanpa await).
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, context: 'PlatformDispatcher');
      return true; // sudah di-handle
    };
  }

  /// Catat satu error. Aman dipanggil dari mana saja (best-effort).
  void record(Object error, StackTrace? stack, {String? context}) {
    final entry = AppErrorEntry(
      error: error.toString(),
      stack: stack?.toString(),
      context: context,
      time: DateTime.now(),
    );
    _entries.addLast(entry);
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }
    debugPrint('🛑 [${context ?? 'app'}] $error');
    _maybeReport(entry);
  }

  /// Kirim ke Supabase (best-effort) kalau memenuhi syarat. Tidak pernah
  /// melempar — crash reporter tidak boleh bikin crash baru.
  void _maybeReport(AppErrorEntry entry) {
    try {
      if (kDebugMode) return; // jangan spam saat dev
      if (_reportsSent >= _maxReportsPerSession) return;
      if (!Env.isSupabaseConfigured) return;
      final hash = Object.hash(entry.error, entry.context);
      if (!_reportedHashes.add(hash)) return; // sudah dikirim sesi ini
      _reportsSent++;
      unawaited(_send(entry));
    } catch (_) {
      // Termasuk kasus Supabase/dotenv belum ter-init (error sangat dini).
    }
  }

  Future<void> _send(AppErrorEntry e) async {
    try {
      final client = Supabase.instance.client;
      String? clip(String? s, int max) =>
          (s != null && s.length > max) ? s.substring(0, max) : s;
      await client.from('crash_logs').insert({
        'user_id': client.auth.currentUser?.id,
        'context': e.context,
        'error': clip(e.error, 2000),
        'stack': clip(e.stack, 4000),
        'platform': defaultTargetPlatform.name,
      });
    } catch (err) {
      debugPrint('crash report send failed: $err');
    }
  }

  void clear() => _entries.clear();
}

/// Satu entri error tersimpan.
class AppErrorEntry {
  const AppErrorEntry({
    required this.error,
    required this.time,
    this.stack,
    this.context,
  });

  final String error;
  final String? stack;
  final String? context;
  final DateTime time;
}

/// Helper: jalankan [body] dalam zone yang menangkap semua uncaught error
/// dan meneruskannya ke [ErrorLogger]. Bungkus `runApp` dengan ini.
Future<void> runGuardedApp(FutureOr<void> Function() body) async {
  await runZonedGuarded<Future<void>>(
    () async => body(),
    (error, stack) =>
        ErrorLogger.instance.record(error, stack, context: 'Zone'),
  );
}
