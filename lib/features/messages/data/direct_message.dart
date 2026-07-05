class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime? readAt;
  final DateTime createdAt;

  bool isFromMe(String myId) => senderId == myId;
  bool get isRead => readAt != null;

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String,
      content: json['content'] as String,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Conversation summary — last message + unread count.
class ConversationPreview {
  const ConversationPreview({
    required this.partnerId,
    required this.lastMessage,
    required this.unreadCount,
  });

  final String partnerId;
  final DirectMessage lastMessage;
  final int unreadCount;
}
