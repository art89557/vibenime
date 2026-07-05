import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import 'badges.dart';

/// User XP + Level state.
class UserXp {
  const UserXp({required this.xp, required this.level});

  final int xp;
  final int level;

  /// Threshold XP untuk level berikutnya: `(level * level) * 100`.
  /// Mirror dari SQL formula: `level = floor(sqrt(xp / 100)) + 1`.
  int get xpToNextLevel {
    final next = level * level * 100;
    return next - xp;
  }

  /// Fraction 0-1 untuk progress bar XP ke next level.
  double get levelProgress {
    final currentLevelMin = (level - 1) * (level - 1) * 100;
    final nextLevelMin = level * level * 100;
    final range = nextLevelMin - currentLevelMin;
    if (range == 0) return 0;
    return ((xp - currentLevelMin) / range).clamp(0.0, 1.0);
  }

  factory UserXp.fromRow(Map<String, dynamic> row) {
    return UserXp(
      xp: (row['xp'] as num?)?.toInt() ?? 0,
      level: (row['level'] as num?)?.toInt() ?? 1,
    );
  }

  static const empty = UserXp(xp: 0, level: 1);
}

/// Repository untuk XP + Badge operations.
class XpRepository {
  String? get _myId => Supabase.instance.client.auth.currentUser?.id;

  /// Add XP ke user current. Return total XP setelah add.
  Future<int> addXp(int amount) async {
    if (!Env.isSupabaseConfigured || _myId == null) return 0;
    try {
      final newXp = await Supabase.instance.client.rpc(
        'add_xp',
        params: {'amount': amount},
      );
      return (newXp as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('addXp failed: $e');
      return 0;
    }
  }

  /// Trigger server-side check badge — server insert row baru kalau criteria
  /// met. Idempotent.
  Future<void> checkAndAwardBadges() async {
    if (!Env.isSupabaseConfigured || _myId == null) return;
    try {
      await Supabase.instance.client.rpc('check_and_award_badges');
    } catch (e) {
      debugPrint('checkAndAwardBadges failed: $e');
    }
  }

  /// Fetch XP + level untuk user current.
  Future<UserXp> getMyXp() async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured) return UserXp.empty;
    try {
      // XP + level sekarang kolom di user_profiles (merged dari user_xp).
      final rows = await Supabase.instance.client
          .from('user_profiles')
          .select('xp, level')
          .eq('user_id', id);
      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return UserXp.empty;
      return UserXp.fromRow(list.first);
    } catch (e) {
      debugPrint('getMyXp failed: $e');
      return UserXp.empty;
    }
  }

  /// Fetch list badge yang sudah di-unlock user.
  Future<Set<Badge>> getMyBadges() async {
    final id = _myId;
    if (id == null || !Env.isSupabaseConfigured) return const {};
    try {
      final rows = await Supabase.instance.client
          .from('user_badges')
          .select('badge_code')
          .eq('user_id', id);
      final result = <Badge>{};
      for (final row in (rows as List).cast<Map<String, dynamic>>()) {
        final code = row['badge_code'] as String?;
        if (code == null) continue;
        final badge = Badge.fromCode(code);
        if (badge != null) result.add(badge);
      }
      return result;
    } catch (e) {
      debugPrint('getMyBadges failed: $e');
      return const {};
    }
  }
}

final xpRepositoryProvider = Provider<XpRepository>((ref) => XpRepository());

final myXpProvider = FutureProvider.autoDispose<UserXp>((ref) async {
  return ref.watch(xpRepositoryProvider).getMyXp();
});

final myBadgesProvider = FutureProvider.autoDispose<Set<Badge>>((ref) async {
  return ref.watch(xpRepositoryProvider).getMyBadges();
});
