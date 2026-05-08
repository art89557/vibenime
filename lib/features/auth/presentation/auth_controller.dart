import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// State global auth: token + user info kalau sudah login.
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AuthUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  /// Cek token saved di splash. Return true kalau ada user valid.
  Future<bool> bootstrap() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hasToken = await _repo.hasValidToken();
      if (!hasToken) {
        state = state.copyWith(isLoading: false, clearUser: true);
        return false;
      }
      final user = await _repo.fetchViewer();
      state = AuthState(user: user);
      return true;
    } catch (e) {
      // Token mungkin expired/invalid → kembali ke login.
      await _repo.signOut();
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Setelah dapat access_token dari WebView, simpan + fetch user info.
  Future<bool> signInWithToken(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.saveToken(token);
      final user = await _repo.fetchViewer();
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
