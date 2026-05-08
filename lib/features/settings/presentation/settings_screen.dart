import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
          'Anda akan keluar dari akun AniList. List Anda tetap aman di server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          // Account card
          if (user != null)
            _AccountCard(
              name: user.name,
              avatarUrl: user.avatarUrl,
              onLogout: () => _confirmLogout(context, ref),
            )
          else
            _GuestCard(
              onLogin: () => context.go(AppRoutes.login),
            ),

          const SizedBox(height: 24),
          _SectionTitle('Tampilan'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            subtitle: const Text('Selalu aktif (default app)'),
            trailing: Switch(value: true, onChanged: null),
          ),

          const SizedBox(height: 16),
          _SectionTitle('Tentang'),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Versi'),
            subtitle: Text('1.0.0+1'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Sumber data'),
            subtitle: Text('AniList API + Sample HLS'),
          ),
          const ListTile(
            leading: Icon(Icons.code_rounded),
            title: Text('Tugas Mobile App Development'),
            subtitle: Text('Flutter + Riverpod + go_router'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.name,
    required this.onLogout,
    this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@$name',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Login via AniList',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textOnDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Logout',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mode Tamu',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Login dengan AniList untuk fitur My List & sync.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textOnDarkMuted,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onLogin,
                child: const Text('Login with AniList'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnDarkMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
