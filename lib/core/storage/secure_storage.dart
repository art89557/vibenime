import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key constants untuk [secureStorageProvider].
///
/// Class dipertahankan walau body kosong — siap di-extend kalau future
/// butuh secure storage (mis. OAuth provider lain, refresh token cache).
/// AniList keys dihapus saat fitur "Sync dengan AniList" dihilangkan.
class SecureStorageKeys {
  SecureStorageKeys._();
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    // Android: pakai EncryptedSharedPreferences (AES-GCM).
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    // iOS: Keychain dengan accessibility unlock.
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    // Web: pakai DOMException-backed localStorage dengan public key wrapper.
    // Catatan: web tidak truly secure (key di localStorage),
    // tapi cukup untuk obfuscate token dari JS console casual.
    webOptions: WebOptions(
      dbName: 'vibenime_secure',
      publicKey: 'vibenime_pk_v1',
    ),
    // macOS & Linux: Keychain / libsecret.
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
    lOptions: LinuxOptions(),
    // Windows: Credential Manager.
    wOptions: WindowsOptions(),
  );
});
