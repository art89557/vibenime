# VibeNime — Testing Guide

Panduan menjalankan + memahami test suite proyek.

---

## 1. Quick Start

```bash
# Install deps (sekali aja setup awal)
flutter pub get

# Run semua test
flutter test

# Run satu file saja
flutter test test/core/utils/youtube_url_test.dart

# Run dengan coverage report (HTML)
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
# Buka coverage/html/index.html di browser
```

---

## 2. Struktur Test

```
test/
├── core/utils/
│   ├── youtube_url_test.dart       # extractYoutubeId + variants
│   └── source_type_test.dart        # SourceType enum parsing
├── shared/
│   ├── models/
│   │   └── anime_test.dart          # Anime.fromAniListMedia
│   └── widgets/
│       └── anime_card_test.dart     # AnimeCard render + interaction
├── features/
│   ├── admin/widgets/
│   │   └── url_pattern_helper_test.dart  # generatePatternUrls + parse
│   ├── library/
│   │   └── sedang_ditonton_card_test.dart  # progress bar logic
│   └── player/
│       └── video_source_test.dart   # VideoSource.fromJson + roundtrip
└── widget_test.dart                 # Smoke (currently skipped)
```

**Total: 7 test files** — 5 unit + 2 widget tests = **44 testcase pass**.

---

## 3. Apa yang Di-cover

### Unit Tests (5 files)

| File | Apa yang dijamin |
| --- | --- |
| `youtube_url_test` | Parse semua format URL YouTube (watch, youtu.be, embed, shorts, bare ID) + edge cases (empty, invalid) |
| `source_type_test` | Enum mapping konsisten, fallback `manual` untuk unknown, `isYoutube` flag akurat |
| `url_pattern_helper_test` | Pattern `{ep:03d}` substitution, range validation (max 200), throw kalau pattern invalid |
| `anime_test` | `Anime.fromAniListMedia` parsing (title fallback, trailer site filter, studios.nodes, optional fields) |
| `video_source_test` | `VideoSource.fromJson` field mapping + defaults, `toInsertJson` exclude id, `copyWith` partial change |

### Widget Tests (2 files)

| File | Apa yang dijamin |
| --- | --- |
| `anime_card_test` | Render title/score/format, panggil onTap, gracefully handle null fields |
| `sedang_ditonton_card_test` | Progress format zero-padded, fraction clamp 0-1, divide-by-zero safe |

---

## 4. Apa yang TIDAK Di-test (Disengaja)

Bagian-bagian berikut **manual QA** karena cost / value:

| Bagian | Kenapa skip |
| --- | --- |
| Repository (HTTP/Supabase) | Butuh mock backend — manual test via app cukup |
| Watch Party realtime sync | Butuh 2 device fisik — verifikasi via Phase 2 checklist |
| Player playback | better_player & youtube_player butuh native context |
| AniList GraphQL | Sandbox isolate gak bisa hit network |
| Splash bootstrap | Skipped (lihat `widget_test.dart`) — timer leak ke isolate |

---

## 5. Test Patterns yang Dipakai

### Pattern A — Pure Function Test
```dart
test('extractYoutubeId parses bare ID', () {
  expect(extractYoutubeId('dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
});
```

### Pattern B — Widget Smoke Test
```dart
testWidgets('render title', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: AnimeCard(anime: anime, onTap: () {})),
  ));
  expect(find.text('Spy x Family'), findsOneWidget);
});
```

### Pattern C — Interaction Test
```dart
testWidgets('panggil onTap', (tester) async {
  var tapped = 0;
  await tester.pumpWidget(... onTap: () => tapped++);
  await tester.tap(find.byType(AnimeCard));
  expect(tapped, 1);
});
```

### Pattern D — Throws Test
```dart
test('throw FormatException kalau invalid', () {
  expect(() => fn(...), throwsA(isA<FormatException>()));
});
```

---

## 6. CI Integration (Optional)

Untuk auto-run di GitHub Actions, tambahkan `.github/workflows/test.yml`:

```yaml
name: test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.x'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

---

## 7. Manual QA Checklist (Watch Party)

Karena unit test tidak cover real-time sync, lakukan manual test 2 device:

- [ ] Device A login Supabase, buka anime, tap "Mulai Pesta Nonton"
- [ ] Device B (no login) buka anime sama, lihat card "1 Pesta aktif"
- [ ] Device B tap "Gabung" → masuk WatchPartyScreen viewer mode
- [ ] Device A play/pause → Device B mengikuti dalam 3 detik
- [ ] Device A seek ke 10:00 → Device B auto-seek
- [ ] Device A chat "halo" → muncul di Device B <2 detik
- [ ] Device B login Supabase + balas chat → muncul di Device A
- [ ] Device A "Akhiri pesta" → Device B lihat "Pesta sudah berakhir"

---

## 8. Troubleshooting

**Q: `flutter test` hang / timeout?**
A: Skip widget_test.dart (sudah diset `skip: true`) — splash bootstrap leak timer.

**Q: Test pass tapi `flutter analyze` warning?**
A: Lint info-level OK; warning dan error harus 0. Cek:
```bash
flutter analyze --no-fatal-infos
```

**Q: Mau test repository tapi butuh Supabase mock?**
A: Pakai `mocktail` (sudah di pubspec dev_dependencies). Pattern:
```dart
class MockSupabaseClient extends Mock implements SupabaseClient {}
```
