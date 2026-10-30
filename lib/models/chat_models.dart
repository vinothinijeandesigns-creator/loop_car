class ChatThread {
  final String threadId;
  final String userName;
  final String lastMessage;
  final DateTime lastTime;
  final int unread;
  final String? avatarUrl;

  ChatThread({
    required this.threadId,
    required this.userName,
    required this.lastMessage,
    required this.lastTime,
    this.unread = 0,
    this.avatarUrl,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json, String currentUserId, Map<String, dynamic>? otherUserProfile) {
    final bool isP1 = json['participant1_id'] == currentUserId;
    final int unreadCount = isP1 ? (json['unread_p1'] ?? 0) : (json['unread_p2'] ?? 0);
    
    String name = "Unknown";
    String? avatar;
    if (otherUserProfile != null) {
      name = "${otherUserProfile['first_name'] ?? ''} ${otherUserProfile['last_name'] ?? ''}".trim();
      if (name.isEmpty) name = "User";
      avatar = otherUserProfile['avatar_url'];
    }

    return ChatThread(
      threadId: json['id'] ?? '',
      userName: name,
      lastMessage: json['last_message'] ?? '',
      lastTime: json['last_time'] != null ? DateTime.parse(json['last_time']).toLocal() : DateTime.now(),
      unread: unreadCount,
      avatarUrl: avatar,
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final DateTime time;
  final bool seen;
  final bool isSystemMessage;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.time,
    this.seen = false,
    this.isSystemMessage = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      senderId: json['sender_id'] ?? '',
      time: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : DateTime.now(),
      seen: json['is_seen'] ?? false,
      isSystemMessage: json['is_system_message'] ?? false,
    );
  }
}
