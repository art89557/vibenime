/// GraphQL queries untuk AniList API.
/// Reference: https://anilist.gitbook.io/anilist-apiv2-docs/
///
/// **Scope: public catalog only.** User-level queries (Viewer,
/// MediaListCollection, SaveMediaListEntry, DeleteMediaListEntry) sudah
/// di-hapus sejak fitur "Sync dengan AniList" dihilangkan. App pakai
/// Supabase untuk identitas user + Hive local untuk favorit.
class AniListQueries {
  AniListQueries._();

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
          popularity
          description(asHtml: false)
          genres
          season
          seasonYear
        }
      }
    }
  ''';

  /// Search anime by title. Pattern **konsisten dengan mediaBrowse**
  /// (yang sudah confirmed working) — nullable variable + simple sort.
  ///
  /// Sebelumnya pakai `$search: String!` (required) + `SEARCH_MATCH` sort
  /// → kembali 0 result. Hipotesis: graphql_flutter punya issue dengan
  /// non-null variable declaration di query level.
  ///
  /// Variables: `$search: String` (nullable), `$page: Int`, `$perPage: Int`
  static const String mediaSearch = r'''
    query MediaSearch(
      $search: String,
      $page: Int = 1,
      $perPage: Int = 25,
      $status: MediaStatus,
      $sort: [MediaSort] = [POPULARITY_DESC, SCORE_DESC]
    ) {
      Page(page: $page, perPage: $perPage) {
        pageInfo { hasNextPage currentPage total }
        media(
          type: ANIME,
          search: $search,
          status: $status,
          sort: $sort,
          isAdult: false
        ) {
          id
          title { romaji english native }
          coverImage { large medium color }
          bannerImage
          description(asHtml: false)
          format
          status
          episodes
          averageScore
          genres
          season
          seasonYear
          startDate { year month day }
          studios(isMain: true) { nodes { name } }
          nextAiringEpisode { episode airingAt timeUntilAiring }
        }
      }
    }
  ''';

  /// Browse anime by filters (no text search). Dipakai untuk pure genre/year/
  /// season/format browse — terpisah dari mediaSearch supaya tiap query
  /// punya parameter list yang minimal.
  ///
  /// Variables (semua optional, minimum salah satu harus diset):
  ///   $genre_in: [String], $seasonYear: Int, $season: MediaSeason,
  ///   $format_in: [MediaFormat], $page, $perPage
  static const String mediaBrowse = r'''
    query MediaBrowse(
      $genre_in: [String],
      $seasonYear: Int,
      $season: MediaSeason,
      $format_in: [MediaFormat],
      $status: MediaStatus,
      $sort: [MediaSort] = [POPULARITY_DESC, SCORE_DESC],
      $page: Int = 1,
      $perPage: Int = 25
    ) {
      Page(page: $page, perPage: $perPage) {
        pageInfo { hasNextPage currentPage total }
        media(
          type: ANIME,
          genre_in: $genre_in,
          seasonYear: $seasonYear,
          season: $season,
          format_in: $format_in,
          status: $status,
          sort: $sort,
          isAdult: false
        ) {
          id
          title { romaji english native }
          coverImage { large medium color }
          bannerImage
          description(asHtml: false)
          format
          status
          episodes
          averageScore
          genres
          season
          seasonYear
          startDate { year month day }
          studios(isMain: true) { nodes { name } }
          nextAiringEpisode { episode airingAt timeUntilAiring }
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
        idMal
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
        characters(perPage: 12, sort: [ROLE, RELEVANCE]) {
          edges {
            role
            node {
              id
              name { full native alternative }
              image { large medium }
              description(asHtml: false)
              gender
              age
              dateOfBirth { month day }
              bloodType
            }
            voiceActors(language: JAPANESE, sort: [RELEVANCE]) {
              id
              name { full }
              image { medium }
              languageV2
            }
          }
        }
        streamingEpisodes {
          title
          thumbnail
          url
          site
        }
        nextAiringEpisode {
          episode
          airingAt
        }
      }
    }
  ''';

  /// Airing schedule untuk range waktu tertentu.
  /// Variables:
  ///   $airingAt_greater: Int  (epoch seconds, mis. Unix timestamp awal hari)
  ///   $airingAt_lesser: Int   (epoch seconds, akhir hari)
  static const String airingSchedule = r'''
    query AiringSchedule($airingAt_greater: Int, $airingAt_lesser: Int) {
      Page(perPage: 50) {
        airingSchedules(
          airingAt_greater: $airingAt_greater,
          airingAt_lesser: $airingAt_lesser,
          sort: TIME
        ) {
          airingAt
          episode
          media {
            id
            title { romaji english native }
            coverImage { medium large }
            format
            status
            averageScore
            popularity
            isAdult
          }
        }
      }
    }
  ''';

  /// Ambil `nextAiringEpisode` untuk banyak anime sekaligus (by id) — dipakai
  /// untuk menjadwalkan notifikasi "episode baru" anime di My List.
  ///
  /// Variables: `$ids: [Int]`
  static const String mediaAiringByIds = r'''
    query MediaAiringByIds($ids: [Int]) {
      Page(perPage: 50) {
        media(id_in: $ids, type: ANIME) {
          id
          title { romaji english }
          nextAiringEpisode { episode airingAt }
        }
      }
    }
  ''';

  /// Ambil `genres` untuk banyak anime sekaligus (by id) — dipakai fitur
  /// "Untuk Kamu" (For You) untuk menghitung afinitas genre dari anime yang
  /// pernah ditonton / di-favorit user.
  ///
  /// Variables: `$ids: [Int]`
  static const String mediaGenresByIds = r'''
    query MediaGenresByIds($ids: [Int]) {
      Page(perPage: 50) {
        media(id_in: $ids, type: ANIME) {
          id
          genres
        }
      }
    }
  ''';
}
