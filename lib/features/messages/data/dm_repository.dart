import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'direct_message.dart';

/// Repository untuk Direct Messages — 1-on-1 chat realtime via Supabase.
class DmRepository {
  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  /// Kirim pesan. Return row hasil insert.
  Future<DirectMessage> sendMessage({
    required String recipientId,
    required String content,
  }) async {
    final myId = _myId;
    if (myId == null) throw StateError('Belum login');
    final trimmed = content.trim();
    if (trimmed.isEmpty) throw ArgumentError('Pesan kosong');
    final row = await Supabase.instance.client
        .from('direct_messages')
        .insert({
          'sender_id': myId,
          'recipient_id': recipientId,
          'content': trimmed,
        })
        .select()
        .single();
    return DirectMessage.fromJson(row);
  }

  /// Mark satu pesan sebagai read (oleh recipient).
  Future<void> markRead(String messageId) async {
    await Supabase.instance.client
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', messageId);
  }

  /// Mark semua pesan dalam conversation sebagai read.
  Future<void> markConversationRead(String partnerId) async {
    final myId = _myId;
    if (myId == null) return;
    await Supabase.instance.client
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('sender_id', partnerId)
        .eq('recipient_id', myId)
        .isFilter('read_at', null);
  }

  /// Get all messages dalam conversation dengan partner, sorted by time.
  Future<List<DirectMessage>> getConversation(String partnerId) async {
    final myId = _myId;
    if (myId == null) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('direct_messages')
          .select()
          .or(
            'and(sender_id.eq.$myId,recipient_id.eq.$partnerId),'
            'and(sender_id.eq.$partnerId,recipient_id.eq.$myId)',
          )
          .order('created_at', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(DirectMessage.fromJson)
          .toList();
    } catch (e) {
      debugPrint('getConversation failed: $e');
      return const [];
    }
  }

  /// Stream perubahan conversation realtime.
  Stream<List<DirectMessage>> watchConversation(String partnerId) {
    final myId = _myId;
    if (myId == null) return const Stream.empty();
    final controller = StreamController<List<DirectMessage>>();
    getConversation(partnerId).then((data) {
      if (!controller.isClosed) controller.add(data);
    });
    final channel = Supabase.instance.client
        .channel('dm:$myId:$partnerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (_) async {
            final fresh = await getConversation(partnerId);
            if (!controller.isClosed) controller.add(fresh);
          },
        )
        .subscribe();
    controller.onCancel = () {
      Supabase.instance.client.removeChannel(channel);
    };
    return controller.stream;
  }

  /// List conversations summary — group by partner, ambil last message
  /// + unread count.
  Future<List<ConversationPreview>> getConversations() async {
    final myId = _myId;
    if (myId == null) return const [];
    try {
      final rows = await Supabase.instance.client
          .from('direct_messages')
          .select()
          .or('sender_id.eq.$myId,recipient_id.eq.$myId')
          .order('created_at', ascending: false)
          .limit(500); // safety cap
      final messages = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(DirectMessage.fromJson)
          .toList();

      // Group by partner
      final byPartner = <String, List<DirectMessage>>{};
      for (final m in messages) {
        final partner = m.senderId == myId ? m.recipientId : m.senderId;
        byPartner.putIfAbsent(partner, () => []).add(m);
      }
      final previews = <ConversationPreview>[];
      for (final entry in byPartner.entries) {
        final list = entry.value;
        if (list.isEmpty) continue;
        // Latest (sorted desc — first)
        final last = list.first;
        // Unread = pesan masuk yang belum read
        final unread = list
            .where((m) => m.recipientId == myId && m.readAt == null)
            .length;
        previews.add(
          ConversationPreview(
            partnerId: entry.key,
            lastMessage: last,
            unreadCount: unread,
          ),
        );
      }
      previews.sort(
        (a, b) => b.lastMessage.createdAt.compareTo(a.lastMessage.createdAt),
      );
      return previews;
    } catch (e) {
      debugPrint('getConversations failed: $e');
      return const [];
    }
  }

  /// Watch conversations list — refresh saat ada DM masuk.
  Stream<List<ConversationPreview>> watchConversations() {
    final myId = _myId;
    if (myId == null) return const Stream.empty();
    final controller = StreamController<List<ConversationPreview>>();
    getConversations().then((data) {
      if (!controller.isClosed) controller.add(data);
    });
    final channel = Supabase.instance.client
        .channel('dm_list:$myId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          callback: (_) async {
            final fresh = await getConversations();
            if (!controller.isClosed) controller.add(fresh);
          },
        )
        .subscribe();
    controller.onCancel = () {
      Supabase.instance.client.removeChannel(channel);
    };
    return controller.stream;
  }

  /// Total unread DM count — buat badge nav.
  Future<int> getTotalUnreadCount() async {
    final myId = _myId;
    if (myId == null) return 0;
    try {
      final rows = await Supabase.instance.client
          .from('direct_messages')
          .select('id')
          .eq('recipient_id', myId)
          .isFilter('read_at', null);
      return (rows as List).length;
    } catch (e) {
      return 0;
    }
  }
}

final dmRepositoryProvider = Provider<DmRepository>((ref) => DmRepository());

final conversationsProvider = StreamProvider<List<ConversationPreview>>((ref) {
  return ref.watch(dmRepositoryProvider).watchConversations();
});

final conversationProvider = StreamProvider.family<List<DirectMessage>, String>(
  (ref, partnerId) {
    return ref.watch(dmRepositoryProvider).watchConversation(partnerId);
  },
);

final totalUnreadDmProvider = Provider<int>((ref) {
  final convos = ref.watch(conversationsProvider).valueOrNull ?? const [];
  return convos.fold(0, (sum, c) => sum + c.unreadCount);
});
