import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../my_list/data/my_list_repository.dart';

/// Repository untuk mutation list user (Add / Update entry).
class ListMutationRepository {
  ListMutationRepository(this._client);

  final AniListClient _client;

  /// Set status anime di list user. Insert kalau belum ada, update kalau ada.
  Future<void> setStatus({
    required int mediaId,
    required ListStatus status,
    int? progress,
    double? score,
  }) async {
    await _client.mutate(
      AniListQueries.saveMediaListEntry,
      variables: {
        'mediaId': mediaId,
        'status': status.apiValue,
        'progress': ?progress,
        'score': ?score,
      },
    );
  }

  /// Hapus entry dari list user.
  Future<void> removeEntry(int entryId) async {
    await _client.mutate(
      AniListQueries.deleteMediaListEntry,
      variables: {'id': entryId},
    );
  }
}

final listMutationRepositoryProvider = Provider<ListMutationRepository>(
  (ref) => ListMutationRepository(ref.watch(anilistClientProvider)),
);
