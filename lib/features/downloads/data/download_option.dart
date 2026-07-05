/// Satu pilihan unduhan (kualitas + URL direct + nama host) untuk picker
/// kualitas di tombol Download. Dibangun dari `data.downloadUrl` API Sanka.
class DownloadOption {
  const DownloadOption({
    required this.quality,
    required this.url,
    required this.host,
    this.direct = true,
  });

  /// Label kualitas, mis. "720p".
  final String quality;

  /// URL unduhan. Kalau [direct] true = URL direct-download (Pixeldrain
  /// api/file, bisa diunduh in-app). Kalau false = URL halaman host
  /// (Acefile/Filedon/dll) yang dibuka di browser untuk diunduh manual.
  final String url;

  /// Nama host asal (mis. "Pixeldrain"/"Acefile") — untuk ditampilkan di picker.
  final String host;

  /// True = bisa diunduh langsung di app; false = buka di browser.
  final bool direct;

  /// Resolve URL halaman **Pixeldrain** ke direct-download API.
  /// `https://pixeldrain.com/u/{id}` atau `.../file/{id}` →
  /// `https://pixeldrain.com/api/file/{id}?download`.
  /// Return null kalau bukan URL Pixeldrain yang dikenali.
  static String? resolvePixeldrain(String pageUrl) {
    final uri = Uri.tryParse(pageUrl.trim());
    if (uri == null) return null;
    if (!uri.host.toLowerCase().contains('pixeldrain')) return null;
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.isEmpty) return null;
    // Pola: /u/{id} atau /file/{id} → id = segmen terakhir.
    final id = segs.last;
    if (id.isEmpty) return null;
    return 'https://pixeldrain.com/api/file/$id?download';
  }
}
