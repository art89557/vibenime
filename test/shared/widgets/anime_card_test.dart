import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibenime/shared/models/anime.dart';
import 'package:vibenime/shared/widgets/anime_card.dart';

/// Smoke test untuk render `AnimeCard`.
///
/// Tujuan: pastikan card tetap bisa render meski cover image kosong (placeholder
/// path), title kepanjangan (truncate), dan score/format optional aman null.
void main() {
  Future<void> pumpCard(WidgetTester tester, Anime anime) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeCard(anime: anime, onTap: () {}),
        ),
      ),
    );
  }

  testWidgets('render title yang dikasih', (tester) async {
    const anime = Anime(
      id: 1,
      title: 'Spy x Family',
      coverImage: '',
      averageScore: 86,
      format: 'TV',
    );
    await pumpCard(tester, anime);
    expect(find.text('Spy x Family'), findsOneWidget);
  });

  testWidgets('render score dari averageScore (dibagi 10, 1 desimal)', (
    tester,
  ) async {
    const anime = Anime(id: 1, title: 'Test', coverImage: '', averageScore: 86);
    await pumpCard(tester, anime);
    expect(find.text('8.6'), findsOneWidget);
  });

  testWidgets('format MOVIE label tampil sebagai "MOVIE"', (tester) async {
    const anime = Anime(id: 1, title: 'Demo', coverImage: '', format: 'MOVIE');
    await pumpCard(tester, anime);
    expect(find.text('MOVIE'), findsOneWidget);
  });

  testWidgets('panggil onTap saat di-tap', (tester) async {
    var tapped = 0;
    const anime = Anime(id: 1, title: 'Tap me', coverImage: '');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimeCard(anime: anime, onTap: () => tapped++),
        ),
      ),
    );
    await tester.tap(find.byType(AnimeCard));
    expect(tapped, 1);
  });

  testWidgets('tanpa score & format, hidden gracefully', (tester) async {
    const anime = Anime(id: 1, title: 'Bare', coverImage: '');
    await pumpCard(tester, anime);
    // Tetap render title, tidak crash kalau averageScore null.
    expect(find.text('Bare'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });
}
