import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/core/utils/youtube_url.dart';

/// Unit tests untuk [extractYoutubeId] — fokus ke happy paths + edge cases
/// yang sering muncul saat user paste link dari mobile YouTube share.
void main() {
  group('extractYoutubeId', () {
    test('parse standard youtube.com/watch URL', () {
      expect(
        extractYoutubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('parse youtu.be short URL with query string', () {
      expect(
        extractYoutubeId('https://youtu.be/dQw4w9WgXcQ?si=abc123'),
        'dQw4w9WgXcQ',
      );
    });

    test('parse embed URL', () {
      expect(
        extractYoutubeId('https://www.youtube.com/embed/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('parse shorts URL', () {
      expect(
        extractYoutubeId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
        'dQw4w9WgXcQ',
      );
    });

    test('accept bare 11-char video ID', () {
      expect(extractYoutubeId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
    });

    test('return null for non-YouTube URL', () {
      expect(extractYoutubeId('https://example.com/video'), isNull);
    });

    test('return null for empty / whitespace', () {
      expect(extractYoutubeId(''), isNull);
      expect(extractYoutubeId('   '), isNull);
    });

    test('return null for invalid bare ID (10 chars)', () {
      expect(extractYoutubeId('dQw4w9WgXc'), isNull);
    });

    test('isYoutubeUrl returns true for valid + false for invalid', () {
      expect(isYoutubeUrl('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(isYoutubeUrl('https://example.com'), isFalse);
    });

    test('youtubeWatchUrl produces canonical watch URL', () {
      expect(
        youtubeWatchUrl('dQw4w9WgXcQ'),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    });
  });
}
