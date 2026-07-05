import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/animation/animations.dart';
import '../../core/i18n/l10n_extension.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/utils/haptic_helper.dart';
// Layar tab di-embed langsung di PageView mobile (swipe antar-tab).
// Dependensi shared→features ini mengikuti preseden app_router.
import '../../features/auth/presentation/app_auth_controller.dart';
import '../../features/discover/presentation/home_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/player/presentation/widgets/mini_player_bar.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import 'offline_banner.dart';

/// Adaptive scaffold dengan 5 tabs (Beranda · Cari · Pustaka · Jadwal · Saya).
///
/// **Layout per breakpoint:**
/// - **Mobile** (< 600px) → [PageView] swipe antar-tab + [_PillNavBar]
///   (pill indicator M3 yang slide + tab profil berupa avatar user)
/// - **Tablet** (600-1024px) → `NavigationRail` (left side, icon + label)
/// - **Desktop** (>= 1024px) → Persistent sidebar (left, 240px)
///
/// Sumber kebenaran index aktif tetap **location router** — swipe & tap
/// sama-sama bermuara ke `context.go`, jadi deep-link/back tetap konsisten.
class MainScaffold extends StatelessWidget {
  const MainScaffold({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const _tabs = [
    _NavTab(
      route: AppRoutes.home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavTab(
      route: AppRoutes.search,
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
    ),
    _NavTab(
      route: AppRoutes.library,
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books_rounded,
    ),
    _NavTab(
      route: AppRoutes.schedule,
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
    ),
    _NavTab(
      route: AppRoutes.profile,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  /// Label tab (terlokalisasi) sesuai urutan [_tabs].
  List<String> _labels(BuildContext context) => [
    context.l10n.navHome,
    context.l10n.navSearch,
    context.l10n.navLibrary,
    context.l10n.navSchedule,
    context.l10n.navProfile,
  ];

  int get _currentIndex {
    final idx = _tabs.indexWhere((t) => location.startsWith(t.route));
    return idx == -1 ? 0 : idx;
  }

  void _onSelect(BuildContext context, int i) => context.go(_tabs[i].route);

  /// Bungkus konten tab dengan [OfflineBanner] di atasnya (muncul saat offline).
  Widget _content() => Column(
    children: [
      const OfflineBanner(),
      Expanded(child: child),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.useSidebar(context)) {
      return _buildDesktop(context);
    }
    if (Breakpoints.useNavigationRail(context)) {
      return _buildTablet(context);
    }
    // Mobile: PageView swipe + pill nav. `child` dari router sengaja tidak
    // dipakai di sini (widget hanya terkonstruksi, tidak masuk tree — layar
    // di-render oleh PageView supaya bisa di-swipe).
    return _MobileShell(index: _currentIndex, labels: _labels(context));
  }

  // ─── Tablet (NavigationRail) ─────────────────────────────────────────
  Widget _buildTablet(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => _onSelect(context, i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.surfaceElevated(context),
            indicatorColor: AppColors.primaryAdaptive(
              context,
            ).withValues(alpha: 0.18),
            selectedIconTheme: IconThemeData(
              color: AppColors.primaryAdaptive(context),
            ),
            unselectedIconTheme: IconThemeData(
              color: AppColors.textMuted(context),
            ),
            destinations: _tabs
                .asMap()
                .entries
                .map(
                  (e) => NavigationRailDestination(
                    icon: Icon(e.value.icon),
                    selectedIcon: Icon(e.value.activeIcon),
                    label: Text(_labels(context)[e.key]),
                  ),
                )
                .toList(),
          ),
          VerticalDivider(width: 1, color: AppColors.borderColor(context)),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  // ─── Desktop (Sidebar) ───────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: AppColors.surfaceElevated(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'VibeNime',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary(context),
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Nav tabs
                for (var i = 0; i < _tabs.length; i++)
                  _SidebarTile(
                    tab: _tabs[i],
                    label: _labels(context)[i],
                    active: i == _currentIndex,
                    onTap: () => _onSelect(context, i),
                  ),
                const Spacer(),
                // Footer credit
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'VibeNime · v1.0.0',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: AppColors.textMuted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: AppColors.borderColor(context)),
          Expanded(child: _content()),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _MobileShell — PageView swipe antar-tab, sinkron dua arah dengan router
// ─────────────────────────────────────────────────────────────────────────

/// Shell mobile: konten = [PageView] 5 layar tab (swipe kiri/kanan),
/// bottom bar = [_PillNavBar].
///
/// **Sinkronisasi dua arah:**
/// - Swipe user → `onPageChanged` → `context.go(route)` → pill ikut slide.
/// - Tap tab / `context.go` dari layar lain → `didUpdateWidget` →
///   `animateToPage`. Guard [_isAnimating] mencegah `onPageChanged` halaman
///   perantara (mis. animasi 0→3 melewati 1,2) ikut memicu `context.go`
///   beruntun (anti feedback-loop & anti transisi patah-patah).
///
/// **Gesture nested:** physics default — gesture arena Flutter otomatis
/// memenangkan drag horizontal untuk scrollable horizontal di dalam halaman
/// (row/carousel Home), jadi PageView hanya merespons drag di area lain.
class _MobileShell extends StatefulWidget {
  const _MobileShell({required this.index, required this.labels});

  final int index;
  final List<String> labels;

  @override
  State<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<_MobileShell> {
  late final PageController _pageCtrl = PageController(
    initialPage: widget.index,
  );

  /// True selama animateToPage programatik berlangsung.
  bool _isAnimating = false;

  /// Layar per tab — urutan HARUS sama dengan [MainScaffold._tabs].
  /// Lazy-built oleh PageView; posisi scroll terjaga via PageStorage.
  static const _pages = <Widget>[
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    ScheduleScreen(),
    ProfileScreen(),
  ];

  @override
  void didUpdateWidget(covariant _MobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index || !_pageCtrl.hasClients) return;
    final current = _pageCtrl.page?.round() ?? oldWidget.index;
    // Perubahan berasal dari swipe → page sudah sesuai, tidak perlu animasi.
    if (current == widget.index) return;

    if (AppAnimations.reduceMotion(context)) {
      _pageCtrl.jumpToPage(widget.index);
      return;
    }
    _isAnimating = true;
    _pageCtrl
        .animateToPage(
          widget.index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _isAnimating = false);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    if (_isAnimating || i == widget.index) return;
    context.go(MainScaffold._tabs[i].route);
  }

  void _onSelect(int i) {
    Haptic.selection();
    if (i != widget.index) context.go(MainScaffold._tabs[i].route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: _onPageChanged,
              children: _pages,
            ),
          ),
          // Mini player (PiP) — docked tepat di atas bottom nav, hanya tampil
          // saat sesi player di-minimize. Self-hides kalau tidak ada sesi.
          const MiniPlayerBar(),
        ],
      ),
      bottomNavigationBar: _PillNavBar(
        index: widget.index,
        labels: widget.labels,
        onSelect: _onSelect,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PillNavBar — bottom nav M3 dengan pill indicator yang slide
// ─────────────────────────────────────────────────────────────────────────

/// Bottom nav custom: pill background di belakang ikon aktif yang **slide
/// mulus** saat pindah tab (tap maupun swipe), label hanya di tab aktif
/// (slot fixed-height supaya tidak ada layout shift), dan tab terakhir
/// berupa avatar profil user ([_NavAvatar]).
class _PillNavBar extends StatelessWidget {
  const _PillNavBar({
    required this.index,
    required this.labels,
    required this.onSelect,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final reduce = AppAnimations.reduceMotion(context);
    final accent = AppColors.primaryAdaptive(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(
          top: BorderSide(color: AppColors.borderColor(context), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemW = constraints.maxWidth / MainScaffold._tabs.length;
              final pillW = math.min(64.0, itemW - 8);
              return Stack(
                children: [
                  // Pill indicator — slide ke posisi tab aktif.
                  AnimatedPositioned(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: index * itemW + (itemW - pillW) / 2,
                    top: 8,
                    width: pillW,
                    height: 32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < MainScaffold._tabs.length; i++)
                        Expanded(child: _buildItem(context, i, accent)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, int i, Color accent) {
    final tab = MainScaffold._tabs[i];
    final active = i == index;
    final isProfileTab = i == MainScaffold._tabs.length - 1;

    return Semantics(
      label: labels[i],
      selected: active,
      button: true,
      child: GestureDetector(
        onTap: () => onSelect(i),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 32,
              child: Center(
                child: isProfileTab
                    ? _NavAvatar(active: active)
                    : Icon(
                        active ? tab.activeIcon : tab.icon,
                        size: 22,
                        color: active ? accent : AppColors.textMuted(context),
                      ),
              ),
            ),
            // Slot label fixed-height — terisi hanya untuk tab aktif,
            // tinggi konstan supaya ikon tidak bergeser.
            SizedBox(
              height: 15,
              child: active
                  ? Center(
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _NavAvatar — foto profil user di tab "Saya"
// ─────────────────────────────────────────────────────────────────────────

/// Avatar bundar user untuk tab profil: render `avatarUrl` dari
/// [appAuthControllerProvider]; fallback inisial username (atau ikon person
/// untuk guest / gagal load). Saat aktif: border accent + scale halus.
class _NavAvatar extends ConsumerWidget {
  const _NavAvatar({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appAuthControllerProvider).user;
    final url = user?.avatarUrl;
    final hasUrl = url != null && url.isNotEmpty;
    final name = user?.username ?? '';
    final accent = AppColors.primaryAdaptive(context);
    final reduce = AppAnimations.reduceMotion(context);

    return AnimatedScale(
      scale: active && !reduce ? 1.12 : 1.0,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? accent : AppColors.borderColor(context),
            width: active ? 1.6 : 1,
          ),
        ),
        child: CircleAvatar(
          radius: 11,
          backgroundColor: AppColors.surfaceElevated(context),
          foregroundImage: hasUrl ? CachedNetworkImageProvider(url) : null,
          // Swallow error → fallback child (inisial/ikon) yang tampil.
          onForegroundImageError: hasUrl ? (_, _) {} : null,
          child: name.isNotEmpty
              ? Text(
                  name[0].toUpperCase(),
                  style: GoogleFonts.roboto(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                )
              : Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: active ? accent : AppColors.textMuted(context),
                ),
        ),
      ),
    );
  }
}

class _NavTab {
  const _NavTab({
    required this.route,
    required this.icon,
    required this.activeIcon,
  });

  final String route;
  final IconData icon;
  final IconData activeIcon;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.tab,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final _NavTab tab;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.primaryAdaptive(context)
        : AppColors.textMuted(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active
            ? AppColors.primaryAdaptive(context).withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  active ? tab.activeIcon : tab.icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active
                        ? AppColors.textPrimary(context)
                        : AppColors.textMuted(context),
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
