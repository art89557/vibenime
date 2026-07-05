# Lottie Assets — Download Required

App pakai Lottie animation untuk empty state + onboarding. Download
file-file berikut dari **LottieFiles** (free, CC0/MIT license) dan
save di folder `assets/lottie/` dengan **nama persis** seperti tertulis.

## Required Files

| Filename | Use | Suggested LottieFiles search |
|----------|-----|------------------------------|
| `empty_library.json` | Empty pustaka di Library | "empty bookshelf" / "empty box" |
| `empty_search.json` | Search no result | "search empty" / "magnifier" |
| `loading_film.json` | Alternative loading state | "film reel loading" |
| `success_check.json` | Add-to-list success feedback | "check success" |
| `onboarding_play.json` | Onboarding slide 1 (welcome) | "play button anime" |
| `onboarding_party.json` | Onboarding slide 2 (social) | "people watching tv" |
| `onboarding_explore.json` | Onboarding slide 3 (explore) | "explore compass" |

## Download Steps

1. Buka https://lottiefiles.com → cari keyword di atas
2. Filter: **Free** + **Lottie JSON** (bukan dotLottie)
3. Click "Download" → pilih **Lottie JSON** format
4. **PENTING**: rename file sesuai nama di tabel
5. Drop ke `D:\VibeNime\assets\lottie\`
6. `flutter pub get` lalu `flutter run`

## Size Budget

Tiap file max **100 KB** supaya APK tidak gemuk. Compressed JSON
biasanya 20-60 KB. Hindari Lottie yang import after-effects raster
images — pakai pure-vector.

## Color Customization

Lottie support color override via `delegate`. Untuk match brand cyan
VibeNime, edit lewat LottieFiles online editor sebelum download
(replace primary color dengan `#5DD3F0`).

## Fallback Behavior

Kalau file belum di-download, `LottieEmptyState` widget akan
gracefully tampilkan icon fallback (`Icons.inbox_outlined` default).
App tidak crash — user lihat ikon static sementara.

## Recommended Free Sets

- https://lottiefiles.com/featured-free-animations
- https://lottiefiles.com/categories/anime
- https://iconscout.com/free-animations (alternative source)
