/// Helper untuk generate URL list dari pattern dengan placeholder atau
/// dari paste list manual.
///
/// Dipakai oleh `AdminBulkScreen` untuk insert banyak episode sekaligus.
library;

/// Pattern placeholder yang didukung:
/// - `{ep}`         → `1`, `2`, `3`, …
/// - `{ep:02d}`     → `01`, `02`, `03`, …
/// - `{ep:03d}`     → `001`, `002`, `003`, …
/// - `{ep:04d}`     → `0001`, `0002`, …
///
/// Regex match `{ep}` atau `{ep:NNd}` dimana N = 1-9.
final _placeholderPattern = RegExp(r'\{ep(?::(\d+)d)?\}');

/// Generate list URL dari pattern dengan placeholder + range episode.
///
/// **Throws** [FormatException] kalau pattern tidak mengandung placeholder
/// `{ep}` (sengaja agar user dapat warning awal).
///
/// ```dart
/// final urls = generatePatternUrls(
///   pattern: 'https://archive.org/.../E{ep:03d}.mp4',
///   from: 1,
///   to: 3,
/// );
/// // ['.../E001.mp4', '.../E002.mp4', '.../E003.mp4']
/// ```
List<String> generatePatternUrls({
  required String pattern,
  required int from,
  required int to,
}) {
  if (!_placeholderPattern.hasMatch(pattern)) {
    throw FormatException(
      'Pattern harus mengandung {ep} atau {ep:NNd}. '
      'Contoh: https://example.com/E{ep:03d}.mp4',
    );
  }
  if (from > to) {
    throw FormatException('Episode "from" ($from) > "to" ($to)');
  }
  if (to - from > 200) {
    throw FormatException(
      'Range terlalu besar (${to - from + 1} episode). Max 200 per batch.',
    );
  }

  final result = <String>[];
  for (int ep = from; ep <= to; ep++) {
    result.add(_substitute(pattern, ep));
  }
  return result;
}

/// Replace placeholder dengan episode number sesuai padding format.
String _substitute(String pattern, int episode) {
  return pattern.replaceAllMapped(_placeholderPattern, (match) {
    final width = match.group(1); // null kalau pakai `{ep}` saja
    if (width == null) return episode.toString();
    final w = int.parse(width);
    return episode.toString().padLeft(w, '0');
  });
}

/// Parse multi-line text input (mode "Paste List") jadi list URL.
///
/// - Trim whitespace per line
/// - Skip baris kosong & komentar `# ...`
/// - Validasi setiap line punya scheme `http://` atau `https://`
///
/// ```dart
/// parseUrlList('''
///   https://example.com/ep1.mp4
///
///   # comment, di-skip
///   https://example.com/ep2.mp4
/// ''');
/// // ['https://example.com/ep1.mp4', 'https://example.com/ep2.mp4']
/// ```
List<String> parseUrlList(String text) {
  final lines = text.split('\n');
  final result = <String>[];
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    if (!line.startsWith('http://') && !line.startsWith('https://')) {
      throw FormatException('URL tidak valid: "$line"');
    }
    result.add(line);
  }
  return result;
}
