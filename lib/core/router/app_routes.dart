class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';

  // Bottom nav 5 tabs
  static const String home = '/home';
  static const String search = '/search';
  static const String library = '/library';
  static const String schedule = '/schedule';
  static const String profile = '/profile';

  // Other routes (accessed from screens)
  static const String settings = '/settings';
  static const String about = '/about';
  static const String genrePicker = '/genre';
  static const String privacyPolicy = '/privacy';
  static const String termsOfService = '/terms';
  static const String editProfile = '/profile/edit';
  static const String notifications = '/notifications';
  static const String storage = '/settings/storage';

  // Social features
  static const String userSearch = '/friends/search';
  static const String friendsList = '/friends';
  static const String friendProfile = '/friends/:userId';
  static String friendProfilePath(String userId) => '/friends/$userId';
  static const String conversations = '/messages';
  static const String dmChat = '/messages/:userId';
  static String dmChatPath(String userId) => '/messages/$userId';
  static const String activityFeed = '/feed';

  // Admin routes (gated by AppUser.isAdmin role check di screen)
  static const String adminPanel = '/admin';
  static const String adminBulk = '/admin/bulk';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminModeration = '/admin/moderation';

  // Peringkat Anime (All Time + Weekly ranking)
  static const String ranking = '/ranking';

  // Riwayat Menonton (watch history timeline)
  static const String history = '/history';

  // Paginated section list (infinite scroll trending/popular/etc)
  static const String discoverSection = '/discover/:section';
  static String discoverSectionPath(String sectionName) =>
      '/discover/$sectionName';

  static const String animeDetail = '/anime/:id';
  static const String player = '/player/:animeId/:episodeId';
  static const String watchParty = '/watch-party/:partyId';

  static String animeDetailPath(String id) => '/anime/$id';
  static String playerPath(String animeId, String episodeId) =>
      '/player/$animeId/$episodeId';
  static String watchPartyPath(String partyId) => '/watch-party/$partyId';
}
