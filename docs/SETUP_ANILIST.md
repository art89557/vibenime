# Panduan Register OAuth Client di AniList

> Estimasi waktu: **5 menit**
> Biaya: **Gratis**
> Output akhir: `client_id` AniList yang dipakai untuk login OAuth di VibeNime.

---

## Mengapa kita butuh ini?

VibeNime memakai fitur **My List Sync** — list "Watching", "Plan to Watch", dst yang tersinkron dengan akun AniList user. Untuk itu kita butuh OAuth.

OAuth = mekanisme login resmi tanpa user kasih password ke kita. User login di halaman AniList sendiri, lalu AniList kasih kita **access token** untuk akses data atas nama user.

Untuk mulai, AniList minta kita daftarkan **aplikasi** dulu agar dapat `client_id`.

---

## Persyaratan

- ✅ Akun **AniList** (gratis, daftar di https://anilist.co)

---

## Langkah 1 — Login ke AniList

1. Buka https://anilist.co
2. Login dengan akun Anda (atau Sign Up dulu kalau belum punya).

---

## Langkah 2 — Buka Developer Settings

1. Klik avatar Anda di kanan atas.
2. Pilih **Settings**.
3. Di sidebar kiri, pilih **Developer**.
4. Atau buka langsung: https://anilist.co/settings/developer

---

## Langkah 3 — Create New Client

Klik tombol **Create New Client**.

Isi form:

| Field | Isi dengan |
| --- | --- |
| **Name** | `VibeNime` |
| **Redirect URL** | `vibenime://auth-callback` |

> ⚠️ **Penting:** Redirect URL **harus** sama persis dengan yang nanti dipakai di kode Flutter (`flutter_web_auth_2`). Tulis huruf kecil semua, tanpa spasi.

Klik **Save**.

---

## Langkah 4 — Catat Client ID

Setelah save, AniList akan menampilkan client baru Anda dengan **Client ID** berupa angka 4–5 digit, contoh:

```
ID: 12345
Name: VibeNime
Redirect URL: vibenime://auth-callback
```

**Salin angka Client ID itu.** Kita akan masukkan ke `.env` sebagai `ANILIST_CLIENT_ID`.

---

## Langkah 5 — URL Authorization (untuk Referensi)

Aplikasi VibeNime nanti akan membuka URL ini untuk memulai OAuth:

```
https://anilist.co/api/v2/oauth/authorize?client_id=12345&response_type=token
```

> `response_type=token` = Implicit Grant. Token langsung diberikan di redirect URL setelah user authorize.

User akan login di halaman AniList → klik **Approve** → AniList redirect ke:

```
vibenime://auth-callback#access_token=eyJhbGc...&token_type=Bearer&expires_in=31536000
```

App Flutter tangkap `access_token` dari fragment URL ini.

---

## Langkah 6 — Endpoint AniList yang Dipakai

Setelah punya `access_token`, semua request ke AniList GraphQL pakai header:

```
Authorization: Bearer eyJhbGc...
Content-Type: application/json
```

**Endpoint GraphQL:**
```
POST https://graphql.anilist.co
```

**Query yang akan dipakai VibeNime:**
- `Viewer` — info user yang login
- `Page(trending,popular,top)` — Discover/Home
- `MediaSearch` — Search
- `MediaDetail` — Anime Detail
- `MediaListCollection` — My List
- `SaveMediaListEntry` — Tambah/Update list

---

## Rate Limit AniList

- **90 request per menit** per IP (untuk request unauth)
- **90 request per menit** per user (untuk request authenticated)

VibeNime menangani ini dengan:
- Cache via `dio_cache_interceptor` (Home: 30 menit, Detail: 1 jam)
- Debounce search (350ms delay setelah user berhenti mengetik)

---

## Troubleshooting

### "Redirect URL mismatch" saat login
- Pastikan `redirect_uri` di AndroidManifest.xml dan kode `flutter_web_auth_2` sama persis dengan yang didaftarkan: `vibenime://auth-callback`.
- Case sensitive! Semua huruf kecil.

### Token expired
- Default lifetime: **1 tahun**.
- Untuk tugas kuliah, nggak akan expired sebelum demo selesai.
- Untuk production, implement refresh dengan re-trigger OAuth flow.

### Mau revoke akses
- User bisa revoke sendiri di https://anilist.co/settings/apps
- Setelah revoke, token jadi invalid dan user perlu login ulang.

---

✅ **Selesai!** Sekarang Anda punya:
- `CONSUMET_BASE_URL` dari [`SETUP_CONSUMET.md`](./SETUP_CONSUMET.md)
- `ANILIST_CLIENT_ID` dari panduan ini

Masukkan keduanya ke file `.env` di root proyek (lihat `.env.example` sebagai template).
