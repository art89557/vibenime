/// Helper untuk parsing URL YouTube dari berbagai format ke video ID 11-char.
///
/// YouTube punya banyak format URL — module ini mengabstraksinya jadi satu API.
///
/// Contoh penggunaan:
/// ```dart
/// final id = extractYoutubeId('https://youtu.be/dQw4w9WgXcQ?si=abc');
/// // id == 'dQw4w9WgXcQ'
///
/// final id2 = extractYoutubeId('not a youtube url');
/// // id2 == null
/// ```
library;

/// Pattern regex untuk match video ID 11-char dari berbagai bentuk URL YouTube.
///
/// Note: video ID YouTube selalu **11 karakter** dan mengandung
/// `[a-zA-Z0-9_-]`.
const _validIdChars = r'[a-zA-Z0-9_-]{11}';

final _youtubePatterns = <RegExp>[
  // Standard watch URL: https://www.youtube.com/watch?v=ABC123
  RegExp(
    r'youtube\.com/watch\?v=('
    '$_validIdChars'
    r')',
  ),
  // Short URL: https://youtu.be/ABC123
  RegExp(
    r'youtu\.be/('
    '$_validIdChars'
    r')',
  ),
  // Embed URL: https://www.youtube.com/embed/ABC123
  RegExp(
    r'youtube\.com/embed/('
    '$_validIdChars'
    r')',
  ),
  // Shorts URL: https://www.youtube.com/shorts/ABC123
  RegExp(
    r'youtube\.com/shorts/('
    '$_validIdChars'
    r')',
  ),
];

final _bareIdPattern = RegExp('^$_validIdChars\$');

/// Extract YouTube video ID dari berbagai format URL.
///
/// Format yang didukung:
/// - `https://www.youtube.com/watch?v=ABC123`
/// - `https://youtu.be/ABC123`
/// - `https://www.youtube.com/embed/ABC123`
/// - `https://www.youtube.com/shorts/ABC123`
/// - `https://m.youtube.com/watch?v=ABC123`
/// - Bare video ID (11 karakter): `ABC123XYZ12`
///
/// Query string tambahan setelah ID (mis. `?si=...&t=30`) akan di-ignore.
///
/// Return `null` kalau input bukan URL YouTube valid.
///
/// ```dart
/// extractYoutubeId('https://youtu.be/dQw4w9WgXcQ?si=abc');
/// // 'dQw4w9WgXcQ'
///
/// extractYoutubeId('dQw4w9WgXcQ');
/// // 'dQw4w9WgXcQ'
///
/// extractYoutubeId('https://example.com/video');
/// // null
/// ```
String? extractYoutubeId(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // Try URL patterns first
  for (final pattern in _youtubePatterns) {
    final match = pattern.firstMatch(trimmed);
    if (match != null) return match.group(1);
  }

  // Fallback: bare 11-char video ID
  if (_bareIdPattern.hasMatch(trimmed)) return trimmed;

  return null;
}

/// True kalau string adalah URL YouTube valid yang bisa di-extract ID-nya.
///
/// Convenient untuk validasi form.
bool isYoutubeUrl(String input) => extractYoutubeId(input) != null;

/// Convert video ID ke URL standar YouTube watch.
///
/// Berguna untuk display / external sharing.
///
/// ```dart
/// youtubeWatchUrl('dQw4w9WgXcQ');
/// // 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
/// ```
String youtubeWatchUrl(String videoId) =>
    'https://www.youtube.com/watch?v=$videoId';
