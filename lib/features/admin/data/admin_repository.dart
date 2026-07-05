import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

/// Model user untuk admin user-management.
class AdminUser {
  const AdminUser({
    required this.userId,
    required this.email,
    required this.username,
    this.avatarUrl,
    required this.role,
    this.bannedAt,
    this.bannedReason,
    required this.createdAt,
  });

  final String userId;
  final String email;
  final String username;
  final String? avatarUrl;
  final String role;
  final DateTime? bannedAt;
  final String? bannedReason;
  final DateTime createdAt;

  bool get isBanned => bannedAt != null;
  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';

  factory AdminUser.fromRow(Map<String, dynamic> row) {
    return AdminUser(
      userId: row['user_id'] as String,
      email: (row['email'] as String?) ?? '',
      username: (row['username'] as String?) ?? 'user',
      avatarUrl: row['avatar_url'] as String?,
      role: (row['role'] as String?) ?? 'user',
      bannedAt: row['banned_at'] == null
          ? null
          : DateTime.parse(row['banned_at'] as String),
      bannedReason: row['banned_reason'] as String?,
      createdAt: row['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(row['created_at'] as String),
    );
  }
}

/// Dashboard stats global.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.signupsToday,
    required this.signupsWeek,
    required this.activeUsers7d,
    required this.totalMessages,
    required this.totalFriendships,
    required this.bannedUsers,
    required this.adminCount,
  });

  final int totalUsers;
  final int signupsToday;
  final int signupsWeek;
  final int activeUsers7d;
  final int totalMessages;
  final int totalFriendships;
  final int bannedUsers;
  final int adminCount;

  factory AdminStats.fromRow(Map<String, dynamic> row) {
    return AdminStats(
      totalUsers: (row['total_users'] as num?)?.toInt() ?? 0,
      signupsToday: (row['signups_today'] as num?)?.toInt() ?? 0,
      signupsWeek: (row['signups_week'] as num?)?.toInt() ?? 0,
      activeUsers7d: (row['active_users_7d'] as num?)?.toInt() ?? 0,
      totalMessages: (row['total_messages'] as num?)?.toInt() ?? 0,
      totalFriendships: (row['total_friendships'] as num?)?.toInt() ?? 0,
      bannedUsers: (row['banned_users'] as num?)?.toInt() ?? 0,
      adminCount: (row['admin_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model pesan untuk moderation.
class AdminMessage {
  const AdminMessage({
    required this.id,
    required this.senderId,
    required this.senderUsername,
    this.recipientId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderUsername;
  final String? recipientId;
  final String content;
  final DateTime createdAt;

  factory AdminMessage.fromRow(Map<String, dynamic> row) {
    return AdminMessage(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      senderUsername: (row['sender_username'] as String?) ?? 'unknown',
      recipientId: row['recipient_id'] as String?,
      content: row['content'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

/// Repository untuk semua admin operations via Supabase RPC.
///
/// Semua RPC sudah role-gated di SQL (sql/admin_roles.sql) — kalau caller
/// bukan admin/super_admin, server akan raise exception.
class AdminRepository {
  Future<AdminStats?> getDashboardStats() async {
    if (!Env.isSupabaseConfigured) return null;
    try {
      final rows = await Supabase.instance.client.rpc('admin_dashboard_stats');
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return null;
      return AdminStats.fromRow(list.first);
    } catch (e) {
      debugPrint('getDashboardStats failed: $e');
      return null;
    }
  }

  Future<List<AdminUser>> listUsers({
    String query = '',
    int limit = 50,
    int offset = 0,
  }) async {
    if (!Env.isSupabaseConfigured) return const [];
    try {
      final rows = await Supabase.instance.client.rpc(
        'admin_list_users',
        params: {'p_query': query, 'p_limit': limit, 'p_offset': offset},
      );
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AdminUser.fromRow)
          .toList();
    } catch (e) {
      debugPrint('listUsers failed: $e');
      return const [];
    }
  }

  Future<void> setRole(String userId, String newRole) async {
    await Supabase.instance.client.rpc(
      'admin_set_role',
      params: {'target_id': userId, 'new_role': newRole},
    );
  }

  Future<void> banUser(String userId, String reason) async {
    await Supabase.instance.client.rpc(
      'admin_ban_user',
      params: {'target_id': userId, 'reason': reason},
    );
  }

  Future<void> unbanUser(String userId) async {
    await Supabase.instance.client.rpc(
      'admin_unban_user',
      params: {'target_id': userId},
    );
  }

  Future<List<AdminMessage>> recentMessages({int limit = 100}) async {
    if (!Env.isSupabaseConfigured) return const [];
    try {
      final rows = await Supabase.instance.client.rpc(
        'admin_recent_messages',
        params: {'p_limit': limit},
      );
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AdminMessage.fromRow)
          .toList();
    } catch (e) {
      debugPrint('recentMessages failed: $e');
      return const [];
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await Supabase.instance.client.rpc(
      'admin_delete_message',
      params: {'message_id': messageId},
    );
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

final adminStatsProvider = FutureProvider.autoDispose<AdminStats?>((ref) async {
  return ref.watch(adminRepositoryProvider).getDashboardStats();
});

final adminUsersProvider = FutureProvider.autoDispose
    .family<List<AdminUser>, String>((ref, query) async {
      return ref.watch(adminRepositoryProvider).listUsers(query: query);
    });

final adminRecentMessagesProvider =
    FutureProvider.autoDispose<List<AdminMessage>>((ref) async {
      return ref.watch(adminRepositoryProvider).recentMessages();
    });
