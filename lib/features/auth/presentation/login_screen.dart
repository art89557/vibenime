import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import 'auth_controller.dart';
import 'auth_webview_screen.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    // Buka in-app WebView. User login di sana, screen pop dengan access_token.
    final token = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const AuthWebViewScreen()),
    );

    if (token == null) return; // user cancel
    if (!context.mounted) return;

    final ok =
        await ref.read(authControllerProvider.notifier).signInWithToken(token);
    if (!context.mounted) return;
    if (ok) {
      context.go(AppRoutes.home);
    } else {
      final error = ref.read(authControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Login gagal')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Selamat datang di VibeNime',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Login dengan AniList untuk menyinkronkan watchlist Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppColors.textOnDarkMuted,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed:
                    state.isLoading ? null : () => _signIn(context, ref),
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(state.isLoading
                    ? 'Memproses...'
                    : 'Login with AniList'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed:
                    state.isLoading ? null : () => context.go(AppRoutes.home),
                child: const Text('Lanjutkan sebagai Tamu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
