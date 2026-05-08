import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/env.dart';
import '../../../core/network/anilist_client.dart';
import '../../../core/network/anilist_queries.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String? avatarUrl;
}

class AuthRepository {
  AuthRepository({
    required this.storage,
    required this.client,
  });

  final FlutterSecureStorage storage;
  final AniListClient client;

  /// Build URL OAuth Implicit Grant ke AniList.
  /// Dipakai oleh AuthWebViewScreen untuk dimuat di in-app WebView.
  String buildAuthorizeUrl() {
    if (Env.anilistClientId == 0) {
      throw ApiException(
        message: 'ANILIST_CLIENT_ID belum di-set di .env',
        source: 'Auth',
      );
    }
    return '${Env.anilistAuthorizeUrl}'
        '?client_id=${Env.anilistClientId}'
        '&response_type=token';
  }

  /// Cek apakah URL adalah callback OAuth, return access_token kalau ada.
  String? extractTokenFromCallback(String url) {
    if (!url.startsWith(Env.oauthRedirectUrl)) return null;
    final fragment = Uri.parse(url).fragment;
    if (fragment.isEmpty) return null;
    final params = Uri.splitQueryString(fragment);
    final token = params['access_token'];
    return (token == null || token.isEmpty) ? null : token;
  }

  /// Simpan token ke secure storage setelah dapat dari WebView callback.
  Future<void> saveToken(String token) async {
    await storage.write(key: SecureStorageKeys.anilistToken, value: token);
  }

  /// Ambil info user yang login (panggil setelah saveToken).
  Future<AuthUser> fetchViewer() async {
    final data = await client.query(AniListQueries.viewer);
    final viewer = data['Viewer'] as Map<String, dynamic>;
    final user = AuthUser(
      id: (viewer['id'] as num).toInt(),
      name: viewer['name'] as String,
      avatarUrl:
          (viewer['avatar'] as Map<String, dynamic>?)?['large'] as String?,
    );
    await storage.write(
        key: SecureStorageKeys.anilistUserId, value: user.id.toString());
    await storage.write(
        key: SecureStorageKeys.anilistUsername, value: user.name);
    return user;
  }

  Future<bool> hasValidToken() async {
    final token = await storage.read(key: SecureStorageKeys.anilistToken);
    return token != null && token.isNotEmpty;
  }

  Future<void> signOut() async {
    await storage.delete(key: SecureStorageKeys.anilistToken);
    await storage.delete(key: SecureStorageKeys.anilistUserId);
    await storage.delete(key: SecureStorageKeys.anilistUsername);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    storage: ref.watch(secureStorageProvider),
    client: ref.watch(anilistClientProvider),
  );
});
