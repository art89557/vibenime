import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import 'friendship.dart';

/// Repository untuk operasi Friend system di Supabase.
///
/// Pattern: write ke tabel `public.friendships`, read juga dari sana
/// dengan filter status. RLS sudah handle authorization (lihat
/// `sql/friendships.sql`).
class FriendsRepository {
  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  /// Kirim friend request — insert row dengan status=pending.
  Future<Friendship> sendRequest(String recipientId) async {
    final myId = _myId;
    if (myId == null) throw StateError('Belum login');
    final row = await Supabase.instance.client
        .from('friendships')
        .insert({
          'requester_id': myId,
          'recipient_id': recipientId,
          'status': 'pending',
        })
        .select()
        .single();
    return Friendship.fromJson(row);
  }

  /// Accept request (sebagai recipient) — update status=accepted.
  Future<void> acceptRequest(String friendshipId) async {
    await Supabase.instance.client
        .from('friendships')
        .update({
          'status': 'accepted',
          'accepted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', friendshipId);
  }

  /// Reject request — hapus row.
  Future<void> rejectRequest(String friendshipId) async {
    await Supabase.instance.client
        .from('friendships')
        .delete()
        .eq('id', friendshipId);
  }

  /// Cancel sent request — same as reject.
  Future<void> cancelRequest(String friendshipId) =>
      rejectRequest(friendshipId);

  /// Block user — upsert dengan status=blocked.
  Future<void> blockUser(String userId) async {
    final myId = _myId;
    if (myId == null) throw StateError('Belum login');
    await Supabase.instance.client.from('friendships').upsert({
      'requester_id': myId,
      'recipient_id': userId,
      'status': 'blocked',
    });
  }

  /// Unblock user — hapus row block.
  Future<void> unblockUser(String userId) async {
    final myId = _myId;
    if (myId == null) return;
    await Supabase.instance.client
        .from('friendships')
        .delete()
        .eq('requester_id', myId)
        .eq('recipient_id', userId)
        .eq('status', 'blocked');
  }

  /// Remove friend — hapus row accepted.
  Future<void> removeFriend(String otherUserId) async {
    final myId = _myId;
    if (myId == null) return;
    // Hapus row apapun directionnya (a→b atau b→a)
    await Supabase.instance.client
        .from('friendships')
        .delete()
        .or(
          'and(requester_id.eq.$myId,recipient_id.eq.$otherUserId),'
          'and(requester_id.eq.$otherUserId,recipient_id.eq.$myId)',
        );
  }

  /// List semua friendship yang melibatkan saya. Caller filter by status.
  Future<List<Friendship>> getAllMyFriendships() async {
    final myId = _myId;
    if (myId == null) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('friendships')
          .select()
          .or('requester_id.eq.$myId,recipient_id.eq.$myId');
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(Friendship.fromJson)
          .toList();
    } catch (e) {
      debugPrint('getAllMyFriendships failed: $e');
      return const [];
    }
  }

  /// Cari user by username via RPC. RPC adalah security definer function
  /// di sql/friendships.sql.
  Future<List<FriendUserProfile>> searchUsers(String query) async {
    if (query.trim().length < 2) return const [];
    if (!Env.isSupabaseConfigured) return const [];
    try {
      final rows = await Supabase.instance.client.rpc(
        'search_users_by_username',
        params: {'query': query.trim()},
      );
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(FriendUserProfile.fromRow)
          .toList();
    } catch (e) {
      debugPrint('searchUsers failed: $e');
      return const [];
    }
  }

  /// Ambil profile user by ID (untuk Friend Profile View).
  Future<FriendUserProfile?> getUserProfile(String userId) async {
    if (!Env.isSupabaseConfigured) return null;
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_user_profile',
        params: {'target_id': userId},
      );
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      return FriendUserProfile.fromRow(list.first);
    } catch (e) {
      debugPrint('getUserProfile failed: $e');
      return null;
    }
  }

  /// Stream perubahan friendship via Supabase Realtime — buat refresh
  /// list otomatis saat ada request baru / accepted / blocked.
  Stream<List<Friendship>> watchFriendships() {
    final myId = _myId;
    if (myId == null) return const Stream.empty();
    final controller = StreamController<List<Friendship>>();
    // Initial fetch
    getAllMyFriendships().then((data) {
      if (!controller.isClosed) controller.add(data);
    });
    // Subscribe Realtime changes
    final channel = Supabase.instance.client
        .channel('friendships:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (_) async {
            final fresh = await getAllMyFriendships();
            if (!controller.isClosed) controller.add(fresh);
          },
        )
        .subscribe();
    controller.onCancel = () {
      Supabase.instance.client.removeChannel(channel);
    };
    return controller.stream;
  }
}

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository();
});
