import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/anime_card.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import 'search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final asyncResults = ref.watch(searchResultsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                onChanged: (val) =>
                    ref.read(searchQueryProvider.notifier).state = val,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Cari anime…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: _buildResults(asyncResults, query),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(AsyncValue results, String query) {
    if (query.trim().length < 2) {
      return _EmptyHint(
        icon: Icons.search,
        message: 'Ketik minimal 2 huruf untuk mulai mencari.\nContoh: "Naruto", "Spy", "One Piece".',
      );
    }
    return results.when(
      loading: () => const AnimeGridSkeleton(),
      error: (e, _) => ErrorRetry(
        message: e.toString(),
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return _EmptyHint(
            icon: Icons.sentiment_dissatisfied_outlined,
            message: 'Tidak ada hasil untuk "$query".',
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
          itemCount: list.length,
          itemBuilder: (_, i) => AnimeCard(
            anime: list[i],
            width: double.infinity,
            onTap: () => context.push(
              AppRoutes.animeDetailPath(list[i].id.toString()),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textOnDarkMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textOnDarkMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
