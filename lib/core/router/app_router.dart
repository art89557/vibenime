import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_bulk_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_form_screen.dart';
import '../../features/admin/presentation/admin_list_screen.dart';
import '../../features/admin/presentation/moderation_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';
import '../../features/player/data/video_catalog_repository.dart';
import '../../features/player/presentation/player_platform_guard.dart';
// player_screen.dart di-import secara transitive lewat player_platform_guard.
import '../../features/anime_detail/presentation/anime_detail_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/discover/data/anime_repository.dart';
import '../../features/discover/presentation/home_screen.dart';
import '../../features/discover/presentation/ranking_screen.dart';
import '../../features/discover/presentation/section_list_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/library/presentation/library_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/friends/presentation/friend_profile_screen.dart';
import '../../features/friends/presentation/friends_list_screen.dart';
import '../../features/friends/presentation/user_search_screen.dart';
import '../../features/messages/presentation/chat_screen.dart';
import '../../features/messages/presentation/conversations_screen.dart';
import '../../features/social/presentation/activity_feed_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/legal/presentation/terms_of_service_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../version/force_update_gate.dart';
import '../../features/search/presentation/genre_picker_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/about_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/storage_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/watch_party/presentation/watch_party_screen.dart';
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
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacyPolicy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.termsOfService,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.storage,
        builder: (context, state) => const StorageScreen(),
      ),
      // Social features
      GoRoute(
        path: AppRoutes.userSearch,
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendsList,
        builder: (context, state) => const FriendsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendProfile,
        builder: (context, state) =>
            FriendProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: AppRoutes.conversations,
        builder: (context, state) => const ConversationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dmChat,
        builder: (context, state) =>
            ChatScreen(partnerId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: AppRoutes.activityFeed,
        builder: (context, state) => const ActivityFeedScreen(),
      ),

      // Settings — di luar shell (akses dari Saya screen)
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.genrePicker,
        builder: (context, state) => const GenrePickerScreen(),
      ),

      // Admin routes (gated by AppUser.isAdmin di AdminListScreen)
      GoRoute(
        path: AppRoutes.adminPanel,
        builder: (context, state) => const AdminListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AdminFormScreen(),
          ),
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final source = state.extra;
              if (source is VideoSource) {
                return AdminFormScreen(existing: source);
              }
              return const AdminFormScreen();
            },
          ),
          GoRoute(
            path: 'bulk',
            builder: (context, state) => const AdminBulkScreen(),
          ),
          GoRoute(
            path: 'dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: 'users',
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path: 'moderation',
            builder: (context, state) => const ModerationScreen(),
          ),
        ],
      ),

      // Shell route untuk BottomNav 5 tabs
      ShellRoute(
        builder: (context, state, child) =>
            MainScaffold(location: state.uri.toString(), child: child),
        routes: [
          // **PENTING:** Tiap `NoTransitionPage` di shell HARUS pakai
          // `key: state.pageKey` — GoRouter generate key unik per route.
          // Tanpa ini, navigate antar tab bisa trigger
          // `keyReservation.contains(key)` assertion di Navigator
          // (red error screen) karena beberapa page share same key.
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ForceUpdateGate(child: HomeScreen()),
            ),
          ),
          GoRoute(
            path: AppRoutes.search,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SearchScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.library,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const LibraryScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.schedule,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ScheduleScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
            ),
          ),
        ],
      ),

      // Peringkat Anime (All Time + Weekly)
      GoRoute(
        path: AppRoutes.ranking,
        builder: (context, state) => const RankingScreen(),
      ),

      // Riwayat Menonton (watch history timeline)
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),

      // Paginated section list (infinite scroll)
      GoRoute(
        path: AppRoutes.discoverSection,
        builder: (context, state) {
          final sectionName = state.pathParameters['section']!;
          final section = DiscoverSection.values.firstWhere(
            (s) => s.name == sectionName,
            orElse: () => DiscoverSection.trending,
          );
          return SectionListScreen(section: section);
        },
      ),

      // Detail & Player di luar shell (full screen)
      GoRoute(
        path: AppRoutes.animeDetail,
        builder: (context, state) =>
            AnimeDetailScreen(animeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.player,
        builder: (context, state) => PlayerPlatformGuard(
          animeId: state.pathParameters['animeId']!,
          episodeId: state.pathParameters['episodeId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.watchParty,
        builder: (context, state) =>
            WatchPartyScreen(partyId: state.pathParameters['partyId']!),
      ),
    ],
  );
});
