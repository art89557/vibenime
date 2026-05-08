import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/my_list_repository.dart';

/// `Map<ListStatus, List<ListEntry>>` — auto-refresh saat user berubah.
final myListProvider = FutureProvider.autoDispose<
    Map<ListStatus, List<ListEntry>>>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) {
    throw StateError('Login dulu untuk lihat list Anda.');
  }
  final repo = ref.watch(myListRepositoryProvider);
  return repo.fetchUserLists(user.id);
});
