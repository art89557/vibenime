/// Character anime dari AniList API — full info untuk tap-to-detail.
///
/// Mapping dari `Media.characters.edges[]`:
/// ```
/// edge.role                        → role (MAIN/SUPPORTING/BACKGROUND)
/// edge.node.id                     → id
/// edge.node.name.full              → name
/// edge.node.name.native            → nativeName (kanji)
/// edge.node.image.large            → imageUrl
/// edge.node.description            → description (markdown ringan)
/// edge.node.gender                 → gender
/// edge.node.age                    → age (string, "16" atau "16-17")
/// edge.node.dateOfBirth.{month,day}→ birthMonthDay
/// edge.node.bloodType              → bloodType
/// edge.voiceActors[0].name.full    → voiceActor (Japanese voice)
/// ```
class Character {
  const Character({
    required this.id,
    required this.name,
    required this.role,
    this.nativeName,
    this.imageUrl,
    this.description,
    this.gender,
    this.age,
    this.birthMonthDay,
    this.bloodType,
    this.voiceActor,
    this.voiceActorImageUrl,
  });

  final int id;
  final String name;

  /// Nama dalam karakter native (kanji/katakana). Optional.
  final String? nativeName;

  /// Role enum AniList: `MAIN`, `SUPPORTING`, `BACKGROUND`.
  /// Untuk display di UI, pakai [roleLabel].
  final String role;

  final String? imageUrl;

  /// Deskripsi karakter (bisa berisi spoiler — AniList kadang tag !~ ~!).
  final String? description;

  /// `Male`, `Female`, `Non-binary`, etc.
  final String? gender;

  /// Umur — string karena AniList kadang return range "16-17".
  final String? age;

  /// Tanggal lahir format "DD MMMM" tanpa tahun (anime characters fictional).
  final String? birthMonthDay;

  final String? bloodType;
  final String? voiceActor;
  final String? voiceActorImageUrl;

  /// Display label friendly untuk role.
  String get roleLabel {
    switch (role) {
      case 'MAIN':
        return 'Utama';
      case 'SUPPORTING':
        return 'Pendukung';
      case 'BACKGROUND':
        return 'Latar';
      default:
        return role;
    }
  }

  /// Format birth date dari `dateOfBirth { month day }`.
  /// Return `null` kalau month atau day null.
  static String? _formatBirthDate(Map<String, dynamic>? dob) {
    if (dob == null) return null;
    final month = dob['month'] as int?;
    final day = dob['day'] as int?;
    if (month == null || day == null) return null;
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    if (month < 1 || month > 12) return null;
    return '$day ${months[month]}';
  }

  /// Build dari single edge `Media.characters.edges[i]`.
  factory Character.fromAniListEdge(Map<String, dynamic> edge) {
    final node = edge['node'] as Map<String, dynamic>? ?? const {};
    final name = node['name'] as Map<String, dynamic>? ?? const {};
    final image = node['image'] as Map<String, dynamic>? ?? const {};
    final dob = node['dateOfBirth'] as Map<String, dynamic>?;
    final voiceActors = (edge['voiceActors'] as List?) ?? const [];

    String? voiceActor;
    String? voiceActorImageUrl;
    if (voiceActors.isNotEmpty) {
      final va = voiceActors.first as Map<String, dynamic>;
      voiceActor = (va['name'] as Map<String, dynamic>?)?['full'] as String?;
      voiceActorImageUrl =
          (va['image'] as Map<String, dynamic>?)?['medium'] as String?;
    }

    return Character(
      id: (node['id'] as num?)?.toInt() ?? 0,
      name: (name['full'] as String?) ?? '?',
      nativeName: name['native'] as String?,
      role: (edge['role'] as String?) ?? 'BACKGROUND',
      imageUrl: (image['large'] ?? image['medium']) as String?,
      description: node['description'] as String?,
      gender: node['gender'] as String?,
      age: node['age'] as String?,
      birthMonthDay: _formatBirthDate(dob),
      bloodType: node['bloodType'] as String?,
      voiceActor: voiceActor,
      voiceActorImageUrl: voiceActorImageUrl,
    );
  }

  /// Build list dari `Media.characters.edges`. Skip entries dengan id=0
  /// (defensive — kadang AniList kasih node null).
  static List<Character> fromAniListEdges(List<dynamic> edges) {
    return edges
        .cast<Map<String, dynamic>>()
        .map(Character.fromAniListEdge)
        .where((c) => c.id != 0)
        .toList();
  }
}
