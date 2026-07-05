import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/features/downloads/data/download_option.dart';

void main() {
  group('DownloadOption.resolvePixeldrain', () {
    test('/u/{id} → api/file direct download', () {
      expect(
        DownloadOption.resolvePixeldrain('https://pixeldrain.com/u/WLsoEtGR'),
        'https://pixeldrain.com/api/file/WLsoEtGR?download',
      );
    });

    test('/file/{id} → api/file direct download', () {
      expect(
        DownloadOption.resolvePixeldrain('https://pixeldrain.com/file/abc123'),
        'https://pixeldrain.com/api/file/abc123?download',
      );
    });

    test('host non-Pixeldrain → null', () {
      expect(
        DownloadOption.resolvePixeldrain('https://krakenfiles.com/view/x/file'),
        isNull,
      );
      expect(
        DownloadOption.resolvePixeldrain('https://vidhidepre.com/file/sia914'),
        isNull,
      );
    });

    test('URL invalid / kosong → null', () {
      expect(DownloadOption.resolvePixeldrain(''), isNull);
      expect(DownloadOption.resolvePixeldrain('pixeldrain.com'), isNull);
    });
  });
}
