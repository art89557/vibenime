import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/my_list_repository.dart';
import 'my_list_providers.dart';

/// 4 tab utama yang ditampilkan (paused & repeating digabung ke "Watching").
const _tabs = <ListStatus>[
  ListStatus.current,
  ListStatus.planning,
  ListStatus.completed,
  ListStatus.dropped,
];

class MyListScreen extends ConsumerWidget {
  const MyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (!authState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('My List')),
        body: _LoginPrompt(),
      );
    }

    final asyncLists = ref.watch(myListProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My List'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            tabs: _tabs.map((s) => Tab(text: s.label)).toList(),
          ),
        ),
        body: asyncLists.when(
          loading: () => const AnimeGridSkeleton(),
          error: (e, _) => ErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(myListProvider),
          ),
          data: (lists) => TabBarView(
            children: _tabs.map((s) {
              final entries = lists[s] ?? const <ListEntry>[];
              return _ListTab(entries: entries, status: s);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ListTab extends StatelessWidget {
  const _ListTab({required this.entries, required this.status});

  final List<ListEntry> entries;
  final ListStatus status;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inbox_outlined,
                size: 56,
                color: AppColors.textOnDarkMuted,
              ),
              const SizedBox(height: 12),
              Text(
                'Belum ada anime di "${status.label}".',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppColors.textOnDarkMuted),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.48,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return AnimeCard(
          anime: e.anime,
          width: double.infinity,
          onTap: () => context.push(AppRoutes.animeDetailPath(e.anime.id.toString())),
        );
      },
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Login dulu untuk melihat list Anda',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'My List tersinkron dengan akun AniList.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textOnDarkMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Login with AniList'),
            ),
          ],
        ),
      ),
    );
  }
}
