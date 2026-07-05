import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/source_type.dart';
import '../../player/data/video_catalog_repository.dart';

/// List semua video sources (untuk admin panel).
final adminVideoSourcesProvider = FutureProvider.autoDispose<List<VideoSource>>(
  (ref) async {
    final repo = ref.watch(videoCatalogRepositoryProvider);
    return repo.fetchAll();
  },
);

/// Filter query (search by anilist_id atau notes).
final adminFilterQueryProvider = StateProvider<String>((ref) => '');

/// Filter source type — null = semua type.
final adminFilterSourceTypeProvider = StateProvider<SourceType?>((ref) => null);

/// Stats summary untuk admin dashboard header.
class AdminStats {
  const AdminStats({
    required this.totalAnime,
    required this.totalSources,
    required this.byType,
  });

  /// Jumlah anime unik di catalog.
  final int totalAnime;

  /// Total semua source row (semua anime x semua episode).
  final int totalSources;

  /// Breakdown count per source type (mis. archive_org: 25, youtube: 10).
  final Map<SourceType, int> byType;
}

/// Derived stats dari semua sources — auto re-eval saat data berubah.
final adminStatsProvider = Provider.autoDispose<AsyncValue<AdminStats>>((ref) {
  final asyncList = ref.watch(adminVideoSourcesProvider);
  return asyncList.whenData((list) {
    final animeIds = list.map((s) => s.anilistId).toSet();
    final byType = <SourceType, int>{};
    for (final s in list) {
      final t = s.sourceTypeEnum;
      byType[t] = (byType[t] ?? 0) + 1;
    }
    return AdminStats(
      totalAnime: animeIds.length,
      totalSources: list.length,
      byType: byType,
    );
  });
});

/// Filtered list — apply text filter + source type filter.
final filteredAdminSourcesProvider =
    Provider.autoDispose<AsyncValue<List<VideoSource>>>((ref) {
      final asyncList = ref.watch(adminVideoSourcesProvider);
      final query = ref.watch(adminFilterQueryProvider).trim().toLowerCase();
      final typeFilter = ref.watch(adminFilterSourceTypeProvider);

      return asyncList.whenData((list) {
        var filtered = list;
        if (typeFilter != null) {
          filtered = filtered
              .where((s) => s.sourceTypeEnum == typeFilter)
              .toList();
        }
        if (query.isNotEmpty) {
          filtered = filtered.where((s) {
            final id = s.anilistId.toString();
            final notes = (s.notes ?? '').toLowerCase();
            return id.contains(query) || notes.contains(query);
          }).toList();
        }
        return filtered;
      });
    });
