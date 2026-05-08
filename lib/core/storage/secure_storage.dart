import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageKeys {
  SecureStorageKeys._();

  static const String anilistToken = 'anilist_access_token';
  static const String anilistUserId = 'anilist_user_id';
  static const String anilistUsername = 'anilist_username';
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});
