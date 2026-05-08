import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/anime_detail/presentation/anime_detail_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/discover/presentation/home_screen.dart';
import '../../features/my_list/presentation/my_list_screen.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // Shell route untuk BottomNav
      ShellRoute(
        builder: (context, state, child) => MainScaffold(
          location: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.search,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.myList,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MyListScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),

      // Detail & Player di luar shell (full screen)
      GoRoute(
        path: AppRoutes.animeDetail,
        builder: (context, state) => AnimeDetailScreen(
          animeId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.player,
        builder: (context, state) => PlayerScreen(
          animeId: state.pathParameters['animeId']!,
          episodeId: state.pathParameters['episodeId']!,
        ),
      ),
    ],
  );
});
