import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav_helper.dart';

/// Terms of Service / Syarat & Ketentuan.
///
/// Konten ringkas Indonesia — wajib di-tampilkan di registrasi dan
/// dapat dibaca dari Settings/About.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Syarat & Ketentuan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => NavHelper.safePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Syarat & Ketentuan VibeNime',
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Terakhir diperbarui: 17 Mei 2026',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: 24),

            _Section(
              title: '1. Penerimaan Syarat',
              body:
                  'Dengan mendaftar dan menggunakan VibeNime ("aplikasi"), '
                  'Anda menyetujui Syarat & Ketentuan ini serta Kebijakan '
                  'Privasi kami. Jika tidak setuju, mohon tidak menggunakan '
                  'aplikasi.',
            ),
            _Section(
              title: '2. Akun Pengguna',
              body:
                  '• Anda bertanggung jawab menjaga kerahasiaan password.\n'
                  '• Satu akun untuk satu pengguna — tidak boleh dibagikan.\n'
                  '• Anda harus berusia minimal 13 tahun.\n'
                  '• Kami berhak menonaktifkan akun yang melanggar ketentuan.',
            ),
            _Section(
              title: '3. Konten & Hak Cipta',
              body:
                  'VibeNime menyediakan akses streaming anime via partner '
                  'streaming sah dan metadata dari AniList (lisensi terbuka). '
                  'Kami **TIDAK** memiliki hak cipta atas anime tersebut. '
                  'Konten user (chat, ulasan) tetap menjadi milik user, tetapi '
                  'Anda memberi kami lisensi non-eksklusif untuk menampilkannya '
                  'di aplikasi.',
            ),
            _Section(
              title: '4. Larangan',
              body:
                  'Dilarang:\n'
                  '• Re-upload atau mendistribusikan ulang konten anime.\n'
                  '• Reverse-engineer aplikasi.\n'
                  '• Spam, harassment, atau ujaran kebencian di chat.\n'
                  '• Mengakses akun pengguna lain tanpa izin.',
            ),
            _Section(
              title: '5. Watch Party & Chat',
              body:
                  'Chat di watch party adalah ruang publik per-party. Anda '
                  'bertanggung jawab atas pesan yang dikirim. Kami berhak '
                  'menghapus pesan yang melanggar dan ban user repeat-offender.',
            ),
            _Section(
              title: '6. Penghentian Layanan',
              body:
                  'Kami berhak menghentikan layanan sewaktu-waktu dengan '
                  'pemberitahuan via aplikasi. Akun Anda dapat dihapus jika '
                  'Anda melanggar ketentuan ini.',
            ),
            _Section(
              title: '7. Disclaimer',
              body:
                  'Aplikasi disediakan "AS-IS" tanpa jaminan apapun. Kami '
                  'tidak bertanggung jawab atas kerugian akibat:\n'
                  '• Downtime server (Supabase / AniList).\n'
                  '• Kehilangan data lokal akibat uninstall.\n'
                  '• Konten partner yang tidak tersedia.',
            ),
            _Section(
              title: '8. Hukum yang Berlaku',
              body:
                  'Syarat ini tunduk pada hukum Republik Indonesia. Sengketa '
                  'diselesaikan secara musyawarah, atau melalui pengadilan '
                  'di Jakarta jika tidak tercapai mufakat.',
            ),
            _Section(
              title: '9. Kontak',
              body: 'Pertanyaan? Email: support@vibenime.app',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: GoogleFonts.roboto(
              fontSize: 14,
              height: 1.55,
              color: AppColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}
