import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:lottie/lottie.dart';

import '../../../core/i18n/l10n_extension.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/haptic_helper.dart';
import '../../../core/theme/app_radius.dart';

/// First-launch onboarding: 3 slide carousel intro VibeNime.
///
/// Flow:
/// 1. Welcome — branding + value prop singkat
/// 2. Fitur — list 4 fitur utama (streaming, download, watch party, chat)
/// 3. Get Started — tombol "Mulai" → tandai seen di Hive → redirect Login
///
/// Splash screen sudah cek flag `onboardingSeen` di Hive — kalau false,
/// redirect ke screen ini sebelum login.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _totalPages = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    Haptic.medium();
    await ref.read(appSettingsProvider.notifier).markOnboardingSeen();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _nextPage() {
    Haptic.light();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — top right
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted(context),
                    ),
                    child: Text(context.l10n.onboardingSkip),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _OnboardingPage(
                    lottieAsset: 'assets/lottie/onboarding_play.json',
                    icon: Icons.play_circle_outline_rounded,
                    title: context.l10n.onboardingTitle1,
                    description: context.l10n.onboardingDesc1,
                    color: AppColors.primary,
                  ),
                  _OnboardingPage(
                    lottieAsset: 'assets/lottie/onboarding_party.json',
                    icon: Icons.featured_play_list_rounded,
                    title: context.l10n.onboardingTitle2,
                    description: context.l10n.onboardingDesc2,
                    color: AppColors.secondary,
                  ),
                  _OnboardingPage(
                    lottieAsset: 'assets/lottie/onboarding_explore.json',
                    icon: Icons.rocket_launch_rounded,
                    title: context.l10n.onboardingTitle3,
                    description: context.l10n.onboardingDesc3,
                    color: AppColors.success,
                  ),
                ],
              ),
            ),

            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryAdaptive(context)
                        : AppColors.borderColor(context),
                    borderRadius: BorderRadius.circular(AppRadius.tiny),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _totalPages - 1
                        ? context.l10n.onboardingStart
                        : context.l10n.onboardingNext,
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.lottieAsset,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final String lottieAsset;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie illustration dengan circular glow di belakang.
          // Fallback ke icon kalau Lottie asset belum di-download.
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.20),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Lottie.asset(
                lottieAsset,
                repeat: true,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(icon, size: 72, color: color),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              color: AppColors.textPrimary(context),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              fontSize: 15,
              color: AppColors.textMuted(context),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
