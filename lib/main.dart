import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/notifications/episode_notification_service.dart';
import 'core/observability/error_logger.dart';
import 'core/storage/hive_init.dart';

Future<void> main() async {
  // Pasang handler error global (lightweight, in-memory) + bungkus app di
  // guarded zone supaya uncaught async error tidak bikin app diam-diam mati.
  await runGuardedApp(() async {
    WidgetsFlutterBinding.ensureInitialized();
    ErrorLogger.instance.install();
    // Pakai font yang sudah di-bundle (assets/fonts) — JANGAN fetch dari
    // network saat runtime. Menghilangkan jank first-paint + flash font.
    GoogleFonts.config.allowRuntimeFetching = false;
    await Env.load();
    await initHive();
    await EpisodeNotificationService.instance.init();

    // Init Supabase kalau credentials sudah di-set di .env.
    // Kalau belum, app tetap jalan dengan fallback ke YouTube/Mux.
    if (Env.isSupabaseConfigured) {
      try {
        await Supabase.initialize(
          url: Env.supabaseUrl,
          anonKey: Env.supabaseAnonKey,
        );
      } catch (e, s) {
        // Init gagal? log saja — repository akan fallback ke null.
        ErrorLogger.instance.record(e, s, context: 'Supabase.initialize');
      }
    }

    runApp(const ProviderScope(child: VibeNimeApp()));
  });
}
