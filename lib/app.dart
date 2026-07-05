import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/locale_provider.dart';
import 'core/notifications/episode_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'l10n/gen/app_localizations.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';

class VibeNimeApp extends ConsumerWidget {
  const VibeNimeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(appSettingsProvider).themeMode;
    final locale = ref.watch(localeProvider);

    // Tap notifikasi episode → buka Detail anime ybs.
    EpisodeNotificationService.instance.onSelectAnime = (id) =>
        router.push(AppRoutes.animeDetailPath(id.toString()));

    return MaterialApp.router(
      title: 'VibeNime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,

      // i18n — locale=null artinya follow system locale
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
