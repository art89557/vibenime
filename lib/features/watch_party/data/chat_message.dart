/// Domain model untuk satu chat message di watch party.
///
/// Mapping ke tabel `chat_messages` di Supabase.
///
/// Type:
/// - `text` — pesan teks biasa
/// - `gift` — emote/gift dengan emoji di field `message`
/// - `system` — auto-message ("@user joined", "host paused", dll)
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.partyId,
    required this.userId,
    required this.username,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  final String id;
  final String partyId;
  final String userId;
  final String username;
  final String? message;
  final String type;
  final DateTime createdAt;

  bool get isText => type == 'text';
  bool get isGift => type == 'gift';
  bool get isSystem => type == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      partyId: json['party_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      message: json['message'] as String?,
      type: (json['type'] as String?) ?? 'text',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
