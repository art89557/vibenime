import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../data/app_auth_repository.dart';

/// State auth aplikasi (Supabase email/password primary).
class AppAuthState {
  const AppAuthState({this.user, this.isLoading = false, this.error});

  final AppUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AppAuthState copyWith({
    AppUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AppAuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Controller untuk auth state. Listen ke Supabase `onAuthStateChange`
/// supaya state UI sync dengan token state (mis. token refresh, sign out
/// dari device lain).
class AppAuthController extends StateNotifier<AppAuthState> {
  AppAuthController(this._repo) : super(const AppAuthState()) {
    _init();
  }

  final AppAuthRepository _repo;
  StreamSubscription<supa.AuthState>? _sub;

  void _init() {
    // Restore dari session yang ada (instant, offline-friendly).
    final existing = _repo.currentUser;
    if (existing != null) {
      state = AppAuthState(user: existing);
    }

    // Listen ke perubahan auth state (signIn/signOut/tokenRefresh).
    _sub = _repo.authStateChanges().listen((auth) {
      final user = auth.session?.user;
      if (user == null) {
        state = const AppAuthState();
      } else {
        state = AppAuthState(user: AppUser.fromSupabase(user));
      }
    });
  }

  /// Sign up + auto-login. Return true kalau sukses.
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signUp(email: email, password: password, username: username);
      // currentUser sudah ke-update via authStateChanges listener.
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('AuthException: ', ''),
      );
      return false;
    }
  }

  /// Sign in. Return true kalau sukses.
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signIn(email: email, password: password);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('AuthException: ', ''),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AppAuthState();
  }

  /// Update profile — semua field opsional. Re-emit state setelah save.
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
    await _repo.updateProfile(
      username: username,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      bio: bio,
      avatarBorder: avatarBorder,
      privacy: privacy,
      clearAvatar: clearAvatar,
      clearBanner: clearBanner,
    );
    final updated = _repo.currentUser;
    if (updated != null) state = AppAuthState(user: updated);
  }

  /// Update email — kirim verify link ke email baru.
  Future<void> updateEmail(String newEmail) async {
    await _repo.updateEmail(newEmail);
  }

  /// Update password — re-auth + update.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _repo.updatePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final appAuthControllerProvider =
    StateNotifierProvider<AppAuthController, AppAuthState>((ref) {
      return AppAuthController(ref.watch(appAuthRepositoryProvider));
    });
