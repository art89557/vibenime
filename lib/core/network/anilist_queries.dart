/// GraphQL queries untuk AniList API.
/// Reference: https://anilist.gitbook.io/anilist-apiv2-docs/
class AniListQueries {
  AniListQueries._();

  /// Info user yang sedang login.
  static const String viewer = r'''
    query Viewer {
      Viewer {
        id
        name
        avatar { large medium }
        bannerImage
      }
    }
  ''';

  /// Discover/Home — bisa dipanggil per section.
  /// Variables:
  ///   $page: Int = 1
  ///   $perPage: Int = 20
  ///   $sort: [MediaSort] (e.g., [TRENDING_DESC], [POPULARITY_DESC], [SCORE_DESC])
  ///   $season: MediaSeason
  ///   $seasonYear: Int
  ///   $status: MediaStatus
  static const String mediaList = r'''
    query MediaList(
      $page: Int = 1,
      $perPage: Int = 20,
      $sort: [MediaSort],
      $season: MediaSeason,
      $seasonYear: Int,
      $status: MediaStatus
    ) {
      Page(page: $page, perPage: $perPage) {
        pageInfo { hasNextPage currentPage total }
        media(
          type: ANIME,
          sort: $sort,
          season: $season,
          seasonYear: $seasonYear,
          status: $status,
          isAdult: false
        ) {
          id
          title { romaji english native }
          coverImage { large medium color }
          bannerImage
          format
          status
          episodes
          averageScore
          genres
          season
          seasonYear
        }
      }
    }
  ''';

  /// Search anime by title.
  /// Variables: $search: String, $page: Int, $perPage: Int
  static const String mediaSearch = r'''
    query MediaSearch($search: String!, $page: Int = 1, $perPage: Int = 25) {
      Page(page: $page, perPage: $perPage) {
        pageInfo { hasNextPage currentPage total }
        media(
          type: ANIME,
          search: $search,
          sort: [SEARCH_MATCH, POPULARITY_DESC],
          isAdult: false
        ) {
          id
          title { romaji english native }
          coverImage { large medium color }
          format
          status
          episodes
          averageScore
          genres
          seasonYear
        }
      }
    }
  ''';

  /// Detail satu anime.
  /// Variables: $id: Int!
  static const String mediaDetail = r'''
    query MediaDetail($id: Int!) {
      Media(id: $id, type: ANIME) {
        id
        title { romaji english native }
        coverImage { large medium color }
        bannerImage
        description(asHtml: false)
        format
        status
        episodes
        duration
        averageScore
        meanScore
        popularity
        genres
        season
        seasonYear
        trailer { id site thumbnail }
        startDate { year month day }
        endDate { year month day }
        studios(isMain: true) { nodes { id name } }
        relations {
          edges {
            relationType
            node {
              id
              title { romaji english native }
              coverImage { medium large }
              format
              type
              episodes
              averageScore
            }
          }
        }
        recommendations(perPage: 10, sort: [RATING_DESC]) {
          nodes {
            mediaRecommendation {
              id
              title { romaji english }
              coverImage { medium }
              averageScore
            }
          }
        }
      }
    }
  ''';

  /// List user (Watching, Planning, Completed, Dropped, Paused, Rewatching).
  /// Variables: $userId: Int!
  static const String mediaListCollection = r'''
    query MediaListCollection($userId: Int!) {
      MediaListCollection(userId: $userId, type: ANIME) {
        lists {
          name
          status
          entries {
            id
            status
            score
            progress
            updatedAt
            media {
              id
              title { romaji english }
              coverImage { large medium }
              episodes
              format
              averageScore
            }
          }
        }
      }
    }
  ''';

  /// Tambah / update entry di list user.
  /// Variables:
  ///   $mediaId: Int!
  ///   $status: MediaListStatus  (CURRENT, PLANNING, COMPLETED, DROPPED, PAUSED, REPEATING)
  ///   $progress: Int
  ///   $score: Float
  static const String saveMediaListEntry = r'''
    mutation SaveMediaListEntry(
      $mediaId: Int!,
      $status: MediaListStatus,
      $progress: Int,
      $score: Float
    ) {
      SaveMediaListEntry(
        mediaId: $mediaId,
        status: $status,
        progress: $progress,
        score: $score
      ) {
        id
        status
        progress
        score
      }
    }
  ''';

  /// Hapus entry list user.
  /// Variables: $id: Int!
  static const String deleteMediaListEntry = r'''
    mutation DeleteMediaListEntry($id: Int!) {
      DeleteMediaListEntry(id: $id) { deleted }
    }
  ''';
}
