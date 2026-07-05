import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/core/utils/source_type.dart';

void main() {
  group('SourceType.fromValue', () {
    test('parse string yang valid → enum match', () {
      expect(SourceType.fromValue('archive_org'), SourceType.archiveOrg);
      expect(SourceType.fromValue('cloudflare_r2'), SourceType.cloudflareR2);
      expect(SourceType.fromValue('mux'), SourceType.mux);
      expect(SourceType.fromValue('youtube'), SourceType.youtube);
      expect(SourceType.fromValue('manual'), SourceType.manual);
    });

    test('fallback ke manual untuk value tidak dikenal', () {
      expect(SourceType.fromValue('unknown_source'), SourceType.manual);
      expect(SourceType.fromValue(''), SourceType.manual);
    });
  });

  group('SourceType getters', () {
    test('isYoutube hanya true untuk SourceType.youtube', () {
      expect(SourceType.youtube.isYoutube, isTrue);
      expect(SourceType.archiveOrg.isYoutube, isFalse);
      expect(SourceType.cloudflareR2.isYoutube, isFalse);
      expect(SourceType.mux.isYoutube, isFalse);
      expect(SourceType.manual.isYoutube, isFalse);
    });

    test('value round-trip: enum.value → fromValue → enum', () {
      for (final t in SourceType.values) {
        expect(SourceType.fromValue(t.value), t);
      }
    });
  });
}
