import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/anime.dart';
import '../data/anime_repository.dart';

final discoverSectionProvider = FutureProvider.family
    .autoDispose<List<Anime>, DiscoverSection>((ref, section) async {
  final repo = ref.watch(animeRepositoryProvider);
  return repo.fetchSection(section, perPage: 12);
});
