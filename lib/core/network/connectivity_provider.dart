import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Status online/offline berbasis `connectivity_plus`.
///
/// `true` = ada interface jaringan aktif (wifi/mobile/ethernet/vpn),
/// `false` = tidak ada (`ConnectivityResult.none`).
///
/// Catatan: ini mendeteksi **interface**, bukan reachability internet penuh —
/// cukup untuk banner "tidak ada koneksi" + memutuskan retry. Saat `loading`
/// (belum ada nilai), konsumen menganggap online (jangan munculkan banner palsu).
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  // Nilai awal (snapshot saat provider pertama dibaca).
  try {
    yield isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    yield true; // gagal cek → asumsikan online (hindari banner palsu)
  }

  // Stream perubahan konektivitas berikutnya.
  yield* connectivity.onConnectivityChanged.map(isOnline);
});
