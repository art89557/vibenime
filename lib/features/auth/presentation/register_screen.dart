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
import '../../../core/theme/app_radius.dart';

/// Register screen — bikin akun Supabase email/password.
///
/// Form: email, username, password, confirm password. Real-time validation
/// (Rule 5 — Prevent Errors): submit button disabled sampai semua field
/// valid + password match.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    // Trigger rebuild saat field berubah supaya button enabled/disabled live.
    for (final c in [_emailCtrl, _usernameCtrl, _passwordCtrl, _confirmCtrl]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [_emailCtrl, _usernameCtrl, _passwordCtrl, _confirmCtrl]) {
      c.removeListener(_onFieldChanged);
      c.dispose();
    }
    super.dispose();
  }

  bool _isValidEmail(String s) {
    final r = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return r.hasMatch(s.trim());
  }

  bool get _isFormValid {
    final email = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    return _isValidEmail(email) &&
        username.length >= 3 &&
        password.length >= 6 &&
        password == confirm &&
        _agreedToTerms;
  }

  String? get _passwordMismatchHint {
    final p = _passwordCtrl.text;
    final c = _confirmCtrl.text;
    if (c.isEmpty) return null;
    if (p != c) return context.l10n.authPasswordMismatch;
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_isFormValid) return;

    Haptic.medium();
    final ok = await ref
        .read(appAuthControllerProvider.notifier)
        .signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          username: _usernameCtrl.text.trim(),
        );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authRegisterSuccess),
          backgroundColor: AppColors.success.withValues(alpha: 0.95),
        ),
      );
      syncWatchHistory(ref); // unggah progress nonton guest ke cloud
      syncFavorites(ref); // unggah My List guest ke cloud
      context.go(AppRoutes.home);
    } else {
      final error = ref.read(appAuthControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? context.l10n.authRegisterFailed),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(appAuthControllerProvider).isLoading;
    final mismatchHint = _passwordMismatchHint;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: Text(
          context.l10n.registerTitle,
          style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                context.l10n.authCreateAccount,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary(context),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.authRegisterSubtitle,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.textMuted(context),
                ),
              ),
              const SizedBox(height: 24),

              // Email
              _Label(context.l10n.loginEmail),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: 'kamu@email.com',
                  prefixIcon: const Icon(
                    Icons.alternate_email_rounded,
                    size: 18,
                  ),
                  suffixIcon: _emailCtrl.text.isEmpty
                      ? null
                      : Icon(
                          _isValidEmail(_emailCtrl.text)
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _isValidEmail(_emailCtrl.text)
                              ? AppColors.success
                              : AppColors.warning,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Username
              _Label(context.l10n.profileUsername),
              TextField(
                controller: _usernameCtrl,
                autocorrect: false,
                enabled: !isLoading,
                maxLength: 20,
                decoration: InputDecoration(
                  hintText: context.l10n.authHintMin3,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    size: 18,
                  ),
                  counterText: '',
                  suffixIcon: _usernameCtrl.text.isEmpty
                      ? null
                      : Icon(
                          _usernameCtrl.text.trim().length >= 3
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: _usernameCtrl.text.trim().length >= 3
                              ? AppColors.success
                              : AppColors.warning,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(height: 14),

              // Password
              _Label(context.l10n.loginPassword),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                enabled: !isLoading,
                decoration: InputDecoration(
                  hintText: context.l10n.authHintMin6,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
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
              const SizedBox(height: 14),

              // Confirm password
              _Label(context.l10n.registerConfirmPassword),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                enabled: !isLoading,
                onSubmitted: (_) => _isFormValid ? _handleRegister() : null,
                decoration: InputDecoration(
                  hintText: context.l10n.authHintRepeatPw,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  errorText: mismatchHint,
                ),
              ),
              const SizedBox(height: 20),

              // ToS + Privacy agreement checkbox — wajib di-centang sebelum
              // tombol "Buat Akun" aktif.
              InkWell(
                onTap: isLoading
                    ? null
                    : () => setState(() => _agreedToTerms = !_agreedToTerms),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: isLoading
                            ? null
                            : (v) =>
                                  setState(() => _agreedToTerms = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text.rich(
                            TextSpan(
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                color: AppColors.textMuted(context),
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(text: context.l10n.authAgreePrefix),
                                TextSpan(
                                  text: context.l10n.authTos,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  recognizer: null,
                                ),
                                const TextSpan(text: ' dan '),
                                TextSpan(
                                  text: context.l10n.authPrivacy,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' VibeNime.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Quick links untuk baca dokumen sebelum centang
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 8),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.push(AppRoutes.termsOfService),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        context.l10n.authReadTos,
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Text(
                      ' · ',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.push(AppRoutes.privacyPolicy),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        context.l10n.authReadPrivacy,
                        style: GoogleFonts.roboto(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: (isLoading || !_isFormValid)
                      ? null
                      : _handleRegister,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.surface(context),
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
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
                          context.l10n.actionRegister,
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.registerHasAccount,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: Text(
                      context.l10n.actionLogin,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
