import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Hasil cek versi yang dipakai splash + home untuk modal force update.
enum VersionStatus {
  /// Current version OK, semua up to date.
  upToDate,

  /// Ada update opsional (current < latest, tapi >= minimum).
  /// UI bisa show banner "Update Tersedia" tapi tidak blocking.
  optionalUpdate,

  /// Current < minimum. App harus di-update — blocking modal,
  /// tidak bisa lanjut ke home tanpa update.
  forceUpdate,

  /// Maintenance mode aktif — semua user di-block dengan pesan downtime.
  maintenance,

  /// Cek gagal (offline / Supabase down). Default ke upToDate
  /// supaya tidak block user.
  unknown,
}

class VersionCheckResult {
  const VersionCheckResult({
    required this.status,
    required this.currentVersion,
    this.minVersion,
    this.latestVersion,
    this.updateUrl,
  });

  final VersionStatus status;
  final String currentVersion;
  final String? minVersion;
  final String? latestVersion;
  final String? updateUrl;
}

/// Provider yang one-shot cek versi app saat startup.
///
/// Logic:
/// 1. Kalau Supabase belum di-init → return [VersionStatus.unknown]
/// 2. Fetch row `min_version_android` + `latest_version_android` dari `app_config`
/// 3. Compare semver dengan `package_info_plus.version`
/// 4. Return status sesuai aturan di atas
///
/// Splash/Home tinggal `ref.watch(versionCheckProvider)` dan show modal
/// kalau status == forceUpdate atau maintenance.
final versionCheckProvider = FutureProvider.autoDispose<VersionCheckResult>((
  ref,
) async {
  final info = await PackageInfo.fromPlatform();
  final currentVersion = info.version;

  // Supabase belum di-init? skip
  if (!Env.isSupabaseConfigured) {
    return VersionCheckResult(
      status: VersionStatus.unknown,
      currentVersion: currentVersion,
    );
  }

  try {
    final rows = await Supabase.instance.client
        .from('app_config')
        .select('key, value');

    final config = <String, String>{
      for (final row in rows as List)
        (row as Map)['key'] as String: row['value'] as String,
    };

    final minVersion = config['min_version_android'];
    final latestVersion = config['latest_version_android'];
    final updateUrl = config['update_url'];
    final maintenanceMode = config['maintenance_mode']?.toLowerCase() == 'true';

    if (maintenanceMode) {
      return VersionCheckResult(
        status: VersionStatus.maintenance,
        currentVersion: currentVersion,
        updateUrl: updateUrl,
      );
    }

    if (minVersion != null && _compareSemver(currentVersion, minVersion) < 0) {
      return VersionCheckResult(
        status: VersionStatus.forceUpdate,
        currentVersion: currentVersion,
        minVersion: minVersion,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
      );
    }

    if (latestVersion != null &&
        _compareSemver(currentVersion, latestVersion) < 0) {
      return VersionCheckResult(
        status: VersionStatus.optionalUpdate,
        currentVersion: currentVersion,
        minVersion: minVersion,
        latestVersion: latestVersion,
        updateUrl: updateUrl,
      );
    }

    return VersionCheckResult(
      status: VersionStatus.upToDate,
      currentVersion: currentVersion,
      minVersion: minVersion,
      latestVersion: latestVersion,
    );
  } catch (e) {
    debugPrint('Version check failed (network/RLS?): $e');
    // Fail open — jangan block user kalau cek gagal
    return VersionCheckResult(
      status: VersionStatus.unknown,
      currentVersion: currentVersion,
    );
  }
});

/// Compare dua semver string (mis. "1.2.3" vs "1.3.0").
/// Return negative kalau a kurang dari b, 0 kalau sama, positive kalau a lebih besar.
/// Pre-release suffix (mis. "1.0.0-beta") di-strip.
int _compareSemver(String a, String b) {
  final pa = _parseSemver(a);
  final pb = _parseSemver(b);
  for (var i = 0; i < 3; i++) {
    final diff = pa[i] - pb[i];
    if (diff != 0) return diff;
  }
  return 0;
}

List<int> _parseSemver(String v) {
  final clean = v.split('-').first.split('+').first; // strip pre-release/meta
  final parts = clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}
