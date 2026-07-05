import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/friends_repository.dart';
import '../data/friendship.dart';

/// Stream semua friendship yang melibatkan me — realtime via Supabase.
final myFriendshipsProvider = StreamProvider<List<Friendship>>((ref) {
  return ref.watch(friendsRepositoryProvider).watchFriendships();
});

/// Filter accepted friends (status = accepted).
final acceptedFriendsProvider = Provider<List<Friendship>>((ref) {
  final all = ref.watch(myFriendshipsProvider).valueOrNull ?? const [];
  return all.where((f) => f.status == FriendshipStatus.accepted).toList();
});

/// Pending request masuk (recipient = me, status = pending).
final incomingPendingProvider = Provider<List<Friendship>>((ref) {
  final me = Supabase.instance.client.auth.currentUser?.id;
  if (me == null) return const [];
  final all = ref.watch(myFriendshipsProvider).valueOrNull ?? const [];
  return all
      .where((f) => f.status == FriendshipStatus.pending && f.recipientId == me)
      .toList();
});

/// Pending request keluar (requester = me, status = pending).
final outgoingPendingProvider = Provider<List<Friendship>>((ref) {
  final me = Supabase.instance.client.auth.currentUser?.id;
  if (me == null) return const [];
  final all = ref.watch(myFriendshipsProvider).valueOrNull ?? const [];
  return all
      .where((f) => f.status == FriendshipStatus.pending && f.requesterId == me)
      .toList();
});

/// Blocked users.
final blockedUsersProvider = Provider<List<Friendship>>((ref) {
  final all = ref.watch(myFriendshipsProvider).valueOrNull ?? const [];
  return all.where((f) => f.status == FriendshipStatus.blocked).toList();
});

/// Count incoming pending — buat badge merah di Profile nav tab.
final pendingRequestCountProvider = Provider<int>((ref) {
  return ref.watch(incomingPendingProvider).length;
});

/// Status friendship dengan user tertentu — buat tahu apakah user X
/// sudah friend, pending, atau blocked.
enum FriendshipState {
  none,
  pendingOutgoing,
  pendingIncoming,
  accepted,
  blocked,
}

final friendshipStateProvider = Provider.family<FriendshipState, String>((
  ref,
  otherUserId,
) {
  final me = Supabase.instance.client.auth.currentUser?.id;
  if (me == null) return FriendshipState.none;
  final all = ref.watch(myFriendshipsProvider).valueOrNull ?? const [];
  for (final f in all) {
    final isPair =
        (f.requesterId == me && f.recipientId == otherUserId) ||
        (f.recipientId == me && f.requesterId == otherUserId);
    if (!isPair) continue;
    if (f.status == FriendshipStatus.blocked) return FriendshipState.blocked;
    if (f.status == FriendshipStatus.accepted) return FriendshipState.accepted;
    if (f.status == FriendshipStatus.pending) {
      return f.requesterId == me
          ? FriendshipState.pendingOutgoing
          : FriendshipState.pendingIncoming;
    }
  }
  return FriendshipState.none;
});

/// Cari user profile by ID (cached per session).
final userProfileProvider = FutureProvider.family<dynamic, String>((
  ref,
  userId,
) async {
  final repo = ref.watch(friendsRepositoryProvider);
  return repo.getUserProfile(userId);
});
