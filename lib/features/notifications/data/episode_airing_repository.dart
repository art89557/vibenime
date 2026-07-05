import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/locale_provider.dart';
import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../../core/notifications/episode_notification_service.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/title_language.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../favorites/data/favorite_entry.dart';
import '../../favorites/data/favorites_repository.dart';

/// Info airing 1 anime untuk dijadwalkan notifikasi.
class EpisodeAiringInfo {
  const EpisodeAiringInfo({
    required this.animeId,
    required this.title,
    required this.episode,
    required this.airingAtUtc,
  });

  final int animeId;
  final String title;
  final int episode;
  final DateTime airingAtUtc;
}

/// Ambil `nextAiringEpisode` untuk daftar anime (1 request).
class EpisodeAiringRepository {
  EpisodeAiringRepository(this._client);

  final AniListClient _client;

  Future<List<EpisodeAiringInfo>> fetchForIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final data = await _client.query(
      AniListQueries.mediaAiringByIds,
      variables: {'ids': ids},
    );
    final media =
        ((data['Page'] as Map<String, dynamic>?)?['media'] as List?) ??
        const [];

    final now = DateTime.now().toUtc();
    final cutoff = now.add(const Duration(days: 30));
    final useEnglish = TitlePref.current == TitleLanguage.english;

    final out = <EpisodeAiringInfo>[];
    for (final m in media.cast<Map<String, dynamic>>()) {
      final nae = m['nextAiringEpisode'] as Map<String, dynamic>?;
      if (nae == null) continue;
      final airingAt = DateTime.fromMillisecondsSinceEpoch(
        (nae['airingAt'] as num).toInt() * 1000,
        isUtc: true,
      );
      if (!airingAt.isAfter(now) || airingAt.isAfter(cutoff)) continue;

      final t = m['title'] as Map<String, dynamic>? ?? const {};
      final romaji = t['romaji'] as String?;
      final english = t['english'] as String?;
      final title =
          (useEnglish ? (english ?? romaji) : (romaji ?? english)) ?? '?';
      out.add(
        EpisodeAiringInfo(
          animeId: (m['id'] as num).toInt(),
          title: title,
          episode: (nae['episode'] as num).toInt(),
          airingAtUtc: airingAt,
        ),
      );
    }
    return out;
  }
}

final episodeAiringRepositoryProvider = Provider<EpisodeAiringRepository>(
  (ref) => EpisodeAiringRepository(ref.watch(anilistClientProvider)),
);

/// Jadwal ulang semua notifikasi episode sesuai setting + My List terkini.
/// Aman dipanggil berkali-kali (cancelAll dulu). No-op kalau setting OFF.
Future<void> rescheduleEpisodeNotifications(WidgetRef ref) async {
  final svc = EpisodeNotificationService.instance;
  final enabled = ref.read(appSettingsProvider).notifEpisodes;
  if (!enabled) {
    await svc.cancelAll();
    return;
  }

  final ids = ref
      .read(favoritesRepositoryProvider)
      .getAll()
      .where(
        (f) =>
            f.status == WatchStatus.watching ||
            f.status == WatchStatus.planning,
      )
      .map((f) => f.animeId)
      .toList();

  if (ids.isEmpty) {
    await svc.cancelAll();
    return;
  }

  List<EpisodeAiringInfo> airing;
  try {
    airing = await ref.read(episodeAiringRepositoryProvider).fetchForIds(ids);
  } catch (_) {
    return; // jaringan gagal → biarkan jadwal lama
  }

  final l10n = _resolveL10n(ref);
  await svc.cancelAll();
  for (final a in airing) {
    await svc.scheduleEpisode(
      animeId: a.animeId,
      airingAtUtc: a.airingAtUtc,
      title: l10n.notifEpisodeTitle,
      body: l10n.notifEpisodeBody(a.episode, a.title),
    );
  }
}

/// AppLocalizations tanpa BuildContext (notif dijadwalkan di luar widget tree).
AppLocalizations _resolveL10n(WidgetRef ref) {
  final loc =
      ref.read(localeProvider) ??
      WidgetsBinding.instance.platformDispatcher.locale;
  final code = loc.languageCode == 'id' ? 'id' : 'en';
  return lookupAppLocalizations(Locale(code));
}
