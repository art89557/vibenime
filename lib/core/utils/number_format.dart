/// Format angka besar jadi ringkas ala "17,2K" / "449,9K" / "111,2M".
///
/// Pakai koma sebagai pemisah desimal (gaya Indonesia). Dipakai untuk metrik
/// "views" (AniList `popularity`) di kartu jadwal + layar Peringkat.
String compactCount(int n) {
  if (n < 0) return '0';
  if (n >= 1000000000) {
    return '${_oneDecimal(n / 1000000000)}B';
  }
  if (n >= 1000000) {
    return '${_oneDecimal(n / 1000000)}M';
  }
  if (n >= 1000) {
    return '${_oneDecimal(n / 1000)}K';
  }
  return '$n';
}

String _oneDecimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
