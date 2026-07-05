# App Icon Assets

Tempatkan file berikut di folder ini sebelum menjalankan generator:

- `icon.png` — 1024×1024 PNG (full square, edge-to-edge). Dipakai sebagai
  base launcher icon Android (semua density: mdpi → xxxhdpi).

- `icon_foreground.png` — 1024×1024 PNG transparent center, area aman ~768×768.
  Dipakai untuk Android adaptive icon (foreground layer, background diisi
  `#0B0E14` lewat config di `pubspec.yaml`).

## Generate Icon

```bash
flutter pub run flutter_launcher_icons
```

## Generate Native Splash

```bash
flutter pub run flutter_native_splash:create
```

## Tools untuk Generate Icon

1. **EasyAppIcon** — https://easyappicon.com (drag PNG, download all sizes)
2. **Figma / Photoshop** — manual export 1024×1024
3. **AI (Midjourney/DALL-E)** — prompt: "minimalist anime streaming app icon,
   cyan gradient, play button, dark background, flat design, 1024x1024"
