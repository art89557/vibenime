import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/play_pulse_logo.dart';
import '../../auth/data/app_auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    // Logo: scale-in dari 0.6 + opacity fade
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    // Text: title slide up, tagline fade-in delayed
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _titleOpacity = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
          ),
        );
    _taglineOpacity = CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );

    // Sequenced: logo → text → bootstrap
    _logoCtrl.forward().then((_) => _textCtrl.forward());
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Tampilkan splash minimal 1.6 detik biar animasi selesai.
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    // **Gate routing:**
    // 1. First launch (onboardingSeen=false) → onboarding
    // 2. Sudah onboard + ada session → home
    // 3. Sudah onboard + no session → login
    final settings = ref.read(appSettingsProvider);
    if (!settings.onboardingSeen) {
      context.go(AppRoutes.onboarding);
      return;
    }

    final hasSession = ref.read(appAuthRepositoryProvider).isAuthenticated;
    context.go(hasSession ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo dengan scale + glow effect
            FadeTransition(
              opacity: _logoOpacity,
              child: ScaleTransition(
                scale: _logoScale,
                child: const PlayPulseLogo(size: 128),
              ),
            ),
            const SizedBox(height: 28),

            // Title — slide up + fade
            FadeTransition(
              opacity: _titleOpacity,
              child: SlideTransition(
                position: _titleSlide,
                child: Text(
                  'VibeNime',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 38,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary(context),
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Tagline — delayed fade-in
            FadeTransition(
              opacity: _taglineOpacity,
              child: Text(
                'Vibe-mu, anime-mu.',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted(context),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Loading indicator — fade in dengan tagline
            FadeTransition(
              opacity: _taglineOpacity,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
