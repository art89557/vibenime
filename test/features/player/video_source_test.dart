import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/core/utils/source_type.dart';
import 'package:vibenime/features/player/data/video_catalog_repository.dart';

void main() {
  group('VideoSource.fromJson', () {
    test('parse semua field dari row Supabase lengkap', () {
      final src = VideoSource.fromJson({
        'id': 'abc-uuid',
        'anilist_id': 4082,
        'episode_number': 3,
        'video_url': 'https://archive.org/E03.mp4',
        'subtitle_url': 'https://x.com/E03.vtt',
        'language': 'id',
        'quality': '720p',
        'source_type': 'archive_org',
        'priority': 50,
        'notes': 'Astro Boy 1963 — EP 3',
      });
      expect(src.id, 'abc-uuid');
      expect(src.anilistId, 4082);
      expect(src.episodeNumber, 3);
      expect(src.videoUrl, 'https://archive.org/E03.mp4');
      expect(src.subtitleUrl, 'https://x.com/E03.vtt');
      expect(src.language, 'id');
      expect(src.quality, '720p');
      expect(src.sourceType, 'archive_org');
      expect(src.priority, 50);
      expect(src.notes, 'Astro Boy 1963 — EP 3');
    });

    test('default values untuk field optional yang null', () {
      final src = VideoSource.fromJson({
        'id': 'abc',
        'anilist_id': 1,
        'episode_number': 1,
        'video_url': 'https://x.com/v.mp4',
      });
      expect(src.subtitleUrl, isNull);
      expect(src.language, 'en');
      expect(src.quality, '480p');
      expect(src.sourceType, 'manual');
      expect(src.notes, isNull);
    });

    test('sourceTypeEnum & isYoutubeSource bekerja konsisten', () {
      final yt = VideoSource.fromJson({
        'id': 'a',
        'anilist_id': 1,
        'episode_number': 1,
        'video_url': 'https://youtube.com/watch?v=abc',
        'source_type': 'youtube',
      });
      expect(yt.sourceTypeEnum, SourceType.youtube);
      expect(yt.isYoutubeSource, isTrue);

      final mp4 = VideoSource.fromJson({
        'id': 'a',
        'anilist_id': 1,
        'episode_number': 1,
        'video_url': 'https://archive.org/x.mp4',
        'source_type': 'archive_org',
      });
      expect(mp4.sourceTypeEnum, SourceType.archiveOrg);
      expect(mp4.isYoutubeSource, isFalse);
    });

    test('toInsertJson exclude id (server-generated)', () {
      const src = VideoSource(
        id: 'should-not-appear',
        anilistId: 1,
        episodeNumber: 2,
        videoUrl: 'https://x.com/v.mp4',
        sourceType: 'manual',
      );
      final json = src.toInsertJson();
      expect(json.containsKey('id'), isFalse);
      expect(json['anilist_id'], 1);
      expect(json['episode_number'], 2);
      expect(json['video_url'], 'https://x.com/v.mp4');
    });

    test('copyWith partial change keeps lainnya intact', () {
      const src = VideoSource(
        id: 'abc',
        anilistId: 1,
        episodeNumber: 1,
        videoUrl: 'https://x.com/v.mp4',
        sourceType: 'manual',
        priority: 100,
      );
      final updated = src.copyWith(priority: 10);
      expect(updated.priority, 10);
      expect(updated.id, 'abc');
      expect(updated.videoUrl, 'https://x.com/v.mp4');
    });
  });
}
