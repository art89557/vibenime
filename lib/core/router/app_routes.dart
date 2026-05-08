class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';

  static const String home = '/home';
  static const String search = '/search';
  static const String myList = '/my-list';
  static const String settings = '/settings';

  static const String animeDetail = '/anime/:id';
  static const String player = '/player/:animeId/:episodeId';

  static String animeDetailPath(String id) => '/anime/$id';
  static String playerPath(String animeId, String episodeId) =>
      '/player/$animeId/$episodeId';
}
