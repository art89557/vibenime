import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/admin/presentation/widgets/url_pattern_helper.dart';

void main() {
  group('generatePatternUrls', () {
    test('substitute {ep} dengan plain integer', () {
      final urls = generatePatternUrls(
        pattern: 'https://example.com/E{ep}.mp4',
        from: 1,
        to: 3,
      );
      expect(urls, [
        'https://example.com/E1.mp4',
        'https://example.com/E2.mp4',
        'https://example.com/E3.mp4',
      ]);
    });

    test('substitute {ep:03d} dengan padded integer 3-digit', () {
      final urls = generatePatternUrls(
        pattern: 'https://example.com/E{ep:03d}.mp4',
        from: 1,
        to: 2,
      );
      expect(urls, [
        'https://example.com/E001.mp4',
        'https://example.com/E002.mp4',
      ]);
    });

    test('substitute {ep:02d} dengan padded 2-digit', () {
      final urls = generatePatternUrls(
        pattern: 'https://example.com/ep{ep:02d}.mp4',
        from: 8,
        to: 10,
      );
      expect(urls, [
        'https://example.com/ep08.mp4',
        'https://example.com/ep09.mp4',
        'https://example.com/ep10.mp4',
      ]);
    });

    test('throw FormatException kalau pattern tanpa placeholder', () {
      expect(
        () => generatePatternUrls(
          pattern: 'https://example.com/static.mp4',
          from: 1,
          to: 3,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throw FormatException kalau from > to', () {
      expect(
        () => generatePatternUrls(
          pattern: 'https://example.com/E{ep}.mp4',
          from: 5,
          to: 1,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throw FormatException untuk range > 200', () {
      expect(
        () => generatePatternUrls(
          pattern: 'https://example.com/E{ep}.mp4',
          from: 1,
          to: 250,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parseUrlList', () {
    test('parse multi-line URL list, trim whitespace', () {
      const input = '''
https://example.com/ep1.mp4
   https://example.com/ep2.mp4
''';
      expect(parseUrlList(input), [
        'https://example.com/ep1.mp4',
        'https://example.com/ep2.mp4',
      ]);
    });

    test('skip baris kosong dan komentar #', () {
      const input = '''
# header comment
https://example.com/ep1.mp4

# spacer
https://example.com/ep2.mp4
''';
      expect(parseUrlList(input).length, 2);
    });

    test('throw FormatException kalau ada line tanpa scheme http(s)', () {
      const input = '''
https://example.com/ok.mp4
ftp://example.com/bad
''';
      expect(() => parseUrlList(input), throwsA(isA<FormatException>()));
    });
  });
}
