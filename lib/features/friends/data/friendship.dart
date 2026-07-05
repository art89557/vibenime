/// Status friendship row di Supabase.
enum FriendshipStatus {
  pending('pending'),
  accepted('accepted'),
  blocked('blocked');

  const FriendshipStatus(this.code);
  final String code;

  static FriendshipStatus fromCode(String? code) {
    for (final s in FriendshipStatus.values) {
      if (s.code == code) return s;
    }
    return FriendshipStatus.pending;
  }
}

/// Model untuk satu row di public.friendships.
class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String requesterId;
  final String recipientId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime? acceptedAt;

  /// Return user ID partner (yang BUKAN me).
  String otherUserId(String myUserId) =>
      requesterId == myUserId ? recipientId : requesterId;

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      recipientId: json['recipient_id'] as String,
      status: FriendshipStatus.fromCode(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
    );
  }
}

/// Minimal user profile untuk display di Friend list / search result /
/// Friend Profile View. Dapat dari RPC `search_users_by_username` atau
/// `get_user_profile`.
class FriendUserProfile {
  const FriendUserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.avatarBorder,
    this.email,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final String? avatarBorder;
  final String? email;

  factory FriendUserProfile.fromRow(Map<String, dynamic> row) {
    return FriendUserProfile(
      id: row['id'] as String,
      username: row['username'] as String? ?? 'user',
      avatarUrl: row['avatar_url'] as String?,
      bannerUrl: row['banner_url'] as String?,
      bio: row['bio'] as String?,
      avatarBorder: row['avatar_border'] as String?,
      email: row['email'] as String?,
    );
  }
}
