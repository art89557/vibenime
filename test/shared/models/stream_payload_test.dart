import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/shared/models/stream_source.dart';

void main() {
  group('StreamPayload getters', () {
    test('isYoutube true hanya kalau youtubeVideoId terisi', () {
      expect(const StreamPayload(youtubeVideoId: 'abc').isYoutube, isTrue);
      expect(const StreamPayload(youtubeVideoId: '').isYoutube, isFalse);
      expect(const StreamPayload().isYoutube, isFalse);
    });

    test('isEmbed true hanya kalau embedUrl terisi', () {
      expect(const StreamPayload(embedUrl: 'https://x/embed').isEmbed, isTrue);
      expect(const StreamPayload(embedUrl: '').isEmbed, isFalse);
      expect(const StreamPayload().isEmbed, isFalse);
    });

    test('primarySource pilih HLS dulu kalau ada', () {
      const payload = StreamPayload(
        sources: [
          StreamSource(url: 'https://x/a.mp4', type: 'mp4'),
          StreamSource(url: 'https://x/b.m3u8', type: 'hls'),
        ],
      );
      expect(payload.primarySource?.url, 'https://x/b.m3u8');
    });

    test('primarySource fallback ke pertama kalau tak ada HLS', () {
      const payload = StreamPayload(
        sources: [StreamSource(url: 'https://x/a.mp4', type: 'mp4')],
      );
      expect(payload.primarySource?.url, 'https://x/a.mp4');
    });

    test('preferredIndonesianSubtitle utamakan indo lalu english', () {
      const payload = StreamPayload(
        subtitles: [
          SubtitleTrack(url: 'en.vtt', language: 'English'),
          SubtitleTrack(url: 'id.vtt', language: 'Indonesia'),
        ],
      );
      expect(payload.preferredIndonesianSubtitle?.url, 'id.vtt');
    });

    test('preferredIndonesianSubtitle fallback english kalau tak ada indo', () {
      const payload = StreamPayload(
        subtitles: [
          SubtitleTrack(url: 'en.vtt', language: 'English'),
          SubtitleTrack(url: 'jp.vtt', language: 'Japanese'),
        ],
      );
      expect(payload.preferredIndonesianSubtitle?.url, 'en.vtt');
    });
  });

  group('StreamSource', () {
    test('isHls deteksi dari type atau ekstensi .m3u8', () {
      expect(const StreamSource(url: 'x/a.m3u8').isHls, isTrue);
      expect(const StreamSource(url: 'x/a', type: 'hls').isHls, isTrue);
      expect(const StreamSource(url: 'x/a.mp4', type: 'mp4').isHls, isFalse);
    });

    test('isLocal deteksi path file lokal', () {
      expect(const StreamSource(url: '/data/x.mp4').isLocal, isTrue);
      expect(const StreamSource(url: r'C:\x.mp4').isLocal, isTrue);
      expect(const StreamSource(url: 'https://x/a.mp4').isLocal, isFalse);
    });
  });
}
