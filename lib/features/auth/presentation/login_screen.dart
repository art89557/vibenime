import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../favorites/data/favorites_sync_coordinator.dart';
import '../../history/data/watch_history_sync_coordinator.dart';
import 'app_auth_controller.dart';

/// Login screen — Supabase email/password (PRIMARY auth aplikasi).
///
/// Replace login lama (AniList OAuth). Sekarang AniList jadi optional
/// connector di Profile screen, bukan path login utama.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authLoginRequired),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    Haptic.medium();
    final ok = await ref
        .read(appAuthControllerProvider.notifier)
        .signIn(email: email, password: password);

    if (!mounted) return;
    if (ok) {
      syncWatchHistory(ref); // tarik progress nonton dari cloud
      syncFavorites(ref); // tarik My List dari cloud
      context.go(AppRoutes.home);
    } else {
      final error = ref.read(appAuthControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? context.l10n.authLoginFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appAuthControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'VibeNime',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.authLoginSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    color: AppColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 36),

                // Email
                _Label(context.l10n.loginEmail),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    hintText: 'kamu@email.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                _Label(context.l10n.loginPassword),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  enabled: !isLoading,
                  onSubmitted: (_) => _handleLogin(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Login button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: isLoading ? null : _handleLogin,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onAccent,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : Text(
                            context.l10n.actionLogin,
                            style: GoogleFonts.roboto(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.l10n.loginNoAccount,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(AppRoutes.register),
                      child: Text(
                        context.l10n.actionRegister,
                        style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(color: AppColors.borderColor(context)),
                const SizedBox(height: 16),

                // Guest mode
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Haptic.light();
                          context.go(AppRoutes.home);
                        },
                  child: Text(
                    context.l10n.authGuestContinue,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),
                Text(
                  context.l10n.authGuestNote,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    color: AppColors.textMuted(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Label(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }
}
