import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/core/settings/subtitle_size.dart';

void main() {
  group('SubtitleSize', () {
    test('fontSize naik seiring ukuran', () {
      expect(
        SubtitleSize.small.fontSize,
        lessThan(SubtitleSize.medium.fontSize),
      );
      expect(
        SubtitleSize.medium.fontSize,
        lessThan(SubtitleSize.large.fontSize),
      );
    });

    test('fromStorage: nilai dikenal → enum benar', () {
      expect(SubtitleSize.fromStorage('small'), SubtitleSize.small);
      expect(SubtitleSize.fromStorage('large'), SubtitleSize.large);
      expect(SubtitleSize.fromStorage('medium'), SubtitleSize.medium);
    });

    test('fromStorage: null/tak dikenal → medium (default)', () {
      expect(SubtitleSize.fromStorage(null), SubtitleSize.medium);
      expect(SubtitleSize.fromStorage('xxl'), SubtitleSize.medium);
    });

    test('storageKey = name', () {
      expect(SubtitleSize.small.storageKey, 'small');
      expect(SubtitleSize.large.storageKey, 'large');
    });
  });
}
