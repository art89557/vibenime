import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../../shared/models/anime.dart';

/// Status entry list di AniList.
enum ListStatus {
  current('CURRENT', 'Watching'),
  planning('PLANNING', 'Planning'),
  completed('COMPLETED', 'Completed'),
  dropped('DROPPED', 'Dropped'),
  paused('PAUSED', 'Paused'),
  repeating('REPEATING', 'Rewatching');

  const ListStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Satu entry di list user — anime + progress.
class ListEntry {
  const ListEntry({
    required this.id,
    required this.anime,
    required this.status,
    this.progress = 0,
    this.score = 0,
  });

  final int id;
  final Anime anime;
  final ListStatus status;
  final int progress;
  final double score;
}

class MyListRepository {
  MyListRepository(this._client);

  final AniListClient _client;

  /// Ambil semua list user, dikelompokkan per status.
  Future<Map<ListStatus, List<ListEntry>>> fetchUserLists(int userId) async {
    final data = await _client.query(
      AniListQueries.mediaListCollection,
      variables: {'userId': userId},
    );
    final lists = (data['MediaListCollection'] as Map<String, dynamic>?)
        ?['lists'] as List? ?? const [];

    final result = <ListStatus, List<ListEntry>>{
      for (final s in ListStatus.values) s: <ListEntry>[],
    };

    for (final raw in lists) {
      final list = raw as Map<String, dynamic>;
      final statusStr = list['status'] as String?;
      final status = ListStatus.values.firstWhere(
        (s) => s.apiValue == statusStr,
        orElse: () => ListStatus.current,
      );
      final entries = (list['entries'] as List?) ?? const [];
      for (final e in entries) {
        final entry = e as Map<String, dynamic>;
        final media = entry['media'] as Map<String, dynamic>?;
        if (media == null) continue;
        result[status]!.add(
          ListEntry(
            id: (entry['id'] as num).toInt(),
            anime: Anime.fromAniListMedia(media),
            status: status,
            progress: (entry['progress'] as num?)?.toInt() ?? 0,
            score: (entry['score'] as num?)?.toDouble() ?? 0,
          ),
        );
      }
    }
    return result;
  }
}

final myListRepositoryProvider = Provider<MyListRepository>(
  (ref) => MyListRepository(ref.watch(anilistClientProvider)),
);
