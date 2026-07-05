import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';

/// User model untuk app-native auth (Supabase email/password).
///
/// Berbeda dari `AuthUser` lama (yang AniList-specific), ini wrap Supabase
/// `User` + ekstrak `username` dari user_metadata.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.username,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.avatarBorder,
    this.privacy = const PrivacyPrefs(),
    this.role,
    this.bannedAt,
    this.bannedReason,
  });

  /// Supabase user UUID — dipakai untuk `host_user_id`, `user_id` di tabel
  /// Watch Party + Discussion.
  final String id;

  final String email;

  /// Display name — dari user_metadata.username. Fallback ke email prefix.
  final String username;

  final String? avatarUrl;

  /// Banner image URL (1500×500). Disimpan di Supabase Storage bucket `banners`.
  final String? bannerUrl;

  /// Bio user, max 200 char.
  final String? bio;

  /// Avatar border code (e.g. 'cyan', 'gold'). Lihat `AvatarBorder` enum.
  final String? avatarBorder;

  /// Privacy preferences per-field.
  final PrivacyPrefs privacy;

  /// Role dari user_profiles.role. Nilai: 'user', 'admin', 'super_admin'.
  final String? role;

  /// Banned timestamp dari user_profiles. Null = active.
  final DateTime? bannedAt;
  final String? bannedReason;

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isBanned => bannedAt != null;

  /// Build dari Supabase [User]. Username diambil dari user_metadata,
  /// fallback ke email prefix kalau kosong.
  factory AppUser.fromSupabase(User user) {
    final meta = user.userMetadata ?? const {};
    final username = (meta['username'] as String?)?.trim();
    final emailPrefix = (user.email ?? 'user').split('@').first;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      username: (username == null || username.isEmpty) ? emailPrefix : username,
      avatarUrl: meta['avatar_url'] as String?,
      bannerUrl: meta['banner_url'] as String?,
      bio: meta['bio'] as String?,
      avatarBorder: meta['avatar_border'] as String?,
      privacy: PrivacyPrefs.fromJson(
        meta['privacy'] as Map<String, dynamic>? ?? const {},
      ),
      role: meta['role'] as String?,
    );
  }

  /// Merge dengan data dari user_profiles row (role, bannedAt, etc.).
  /// Pakai setelah `fromSupabase` dan fetch row.
  AppUser mergeProfile(Map<String, dynamic>? row) {
    if (row == null) return this;
    return AppUser(
      id: id,
      email: email,
      username: (row['username'] as String?) ?? username,
      avatarUrl: (row['avatar_url'] as String?) ?? avatarUrl,
      bannerUrl: (row['banner_url'] as String?) ?? bannerUrl,
      bio: (row['bio'] as String?) ?? bio,
      avatarBorder: (row['avatar_border'] as String?) ?? avatarBorder,
      privacy: privacy,
      role: (row['role'] as String?) ?? role,
      bannedAt: row['banned_at'] == null
          ? null
          : DateTime.parse(row['banned_at'] as String),
      bannedReason: row['banned_reason'] as String?,
    );
  }
}

/// Privacy preferences user — 4 toggle granular yang disimpan di
/// user_metadata.privacy sebagai JSON object.
class PrivacyPrefs {
  const PrivacyPrefs({
    this.showStats = true,
    this.showActivity = true,
    this.showFavorites = true,
    this.allowFriendRequests = true,
  });

  /// Tampilkan stat counter (judul, ep, jam, favorit) di profile saya
  /// untuk user lain.
  final bool showStats;

  /// Aktivitas saya (watched, added, completed) muncul di feed friends.
  final bool showActivity;

  /// List favorit saya visible untuk friend.
  final bool showFavorites;

  /// Apakah user lain boleh kirim friend request ke saya.
  final bool allowFriendRequests;

  Map<String, dynamic> toJson() => {
    'show_stats': showStats,
    'show_activity': showActivity,
    'show_favorites': showFavorites,
    'allow_friend_requests': allowFriendRequests,
  };

  factory PrivacyPrefs.fromJson(Map<String, dynamic> json) {
    return PrivacyPrefs(
      showStats: json['show_stats'] as bool? ?? true,
      showActivity: json['show_activity'] as bool? ?? true,
      showFavorites: json['show_favorites'] as bool? ?? true,
      allowFriendRequests: json['allow_friend_requests'] as bool? ?? true,
    );
  }

  PrivacyPrefs copyWith({
    bool? showStats,
    bool? showActivity,
    bool? showFavorites,
    bool? allowFriendRequests,
  }) {
    return PrivacyPrefs(
      showStats: showStats ?? this.showStats,
      showActivity: showActivity ?? this.showActivity,
      showFavorites: showFavorites ?? this.showFavorites,
      allowFriendRequests: allowFriendRequests ?? this.allowFriendRequests,
    );
  }
}

/// Repository unified untuk auth aplikasi.
///
/// **Supabase email/password sebagai PRIMARY auth**:
/// - Tiap user register lewat aplikasi → Supabase Auth signup
/// - Identity ini dipakai di seluruh fitur: Watch Party, Discussion, Admin
/// - AniList OAuth jadi optional connector (di Profile) untuk sync My List
///
/// Replaces `AdminAuthRepository` yang sebelumnya khusus admin saja.
class AppAuthRepository {
  /// Sign up user baru. Auto-login setelah sukses.
  ///
  /// Throw [AuthException] dengan pesan ramah Indonesia kalau:
  /// - Email sudah dipakai
  /// - Password lemah (<6 char by default)
  /// - Format email invalid
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    _ensureSupabase();
    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
    } on AuthException catch (e) {
      throw AuthException(_friendlyError(e.message));
    }
  }

  /// Sign in dengan email + password.
  Future<void> signIn({required String email, required String password}) async {
    _ensureSupabase();
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthException(_friendlyError(e.message));
    }
  }

  /// Sign out — clear Supabase session.
  Future<void> signOut() async {
    if (!Env.isSupabaseConfigured) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('signOut error: $e');
    }
  }

  /// Update profile — semua field optional. Hanya field non-null yang
  /// di-update di user_metadata. `clearAvatar` / `clearBanner` set ke null
  /// (hapus image).
  Future<void> updateProfile({
    String? username,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? avatarBorder,
    PrivacyPrefs? privacy,
    bool clearAvatar = false,
    bool clearBanner = false,
  }) async {
    _ensureSupabase();
    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (clearAvatar) updates['avatar_url'] = null;
    if (bannerUrl != null) updates['banner_url'] = bannerUrl;
    if (clearBanner) updates['banner_url'] = null;
    if (bio != null) updates['bio'] = bio;
    if (avatarBorder != null) updates['avatar_border'] = avatarBorder;
    if (privacy != null) updates['privacy'] = privacy.toJson();
    if (updates.isEmpty) return;
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: updates),
    );
  }

  /// Update email — Supabase kirim verify link ke email baru. Email lama
  /// tetap aktif sampai user click link. Setelah verify, email otomatis
  /// switch.
  Future<void> updateEmail(String newEmail) async {
    _ensureSupabase();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );
    } on AuthException catch (e) {
      throw AuthException(_friendlyError(e.message));
    }
  }

  /// Update password — re-auth dengan password lama dulu sebagai security
  /// check, lalu update.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _ensureSupabase();
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || currentUser.email == null) {
      throw const AuthException('Tidak ada user login.');
    }
    try {
      // Re-auth: verify current password by re-signing-in
      await Supabase.instance.client.auth.signInWithPassword(
        email: currentUser.email!,
        password: currentPassword,
      );
      // Update password baru
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw AuthException(_friendlyError(e.message));
    }
  }

  /// Kirim password reset email — alternative kalau user lupa password lama.
  Future<void> sendPasswordReset(String email) async {
    _ensureSupabase();
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthException(_friendlyError(e.message));
    }
  }

  /// Current authenticated user — null kalau belum login.
  AppUser? get currentUser {
    if (!Env.isSupabaseConfigured) return null;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return AppUser.fromSupabase(user);
  }

  /// Quick check tanpa fetch user object.
  bool get isAuthenticated {
    if (!Env.isSupabaseConfigured) return false;
    return Supabase.instance.client.auth.currentUser != null;
  }

  /// Stream auth state changes — UI bisa watch untuk reactive update
  /// (mis. saat token refresh / signOut / signIn).
  Stream<AuthState> authStateChanges() {
    if (!Env.isSupabaseConfigured) return const Stream.empty();
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  void _ensureSupabase() {
    if (!Env.isSupabaseConfigured) {
      throw const AuthException(
        'Supabase belum di-konfigurasi. Tambah SUPABASE_URL & SUPABASE_ANON_KEY di .env.',
      );
    }
  }

  /// Translate Supabase auth error ke pesan Indonesia.
  static String _friendlyError(String original) {
    final lower = original.toLowerCase();
    if (lower.contains('user already registered') ||
        lower.contains('already exists')) {
      return 'Email ini sudah terdaftar. Coba login.';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'Email atau password salah.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password minimal 6 karakter.';
    }
    if (lower.contains('invalid email')) {
      return 'Format email tidak valid.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox kamu.';
    }
    if (lower.contains('rate limit')) {
      return 'Terlalu banyak percobaan. Tunggu sebentar.';
    }
    return original;
  }
}

final appAuthRepositoryProvider = Provider<AppAuthRepository>(
  (ref) => AppAuthRepository(),
);
