class ChatMessage {
  final int? id;
  final String sender;
  final String message;
  final DateTime originalTimestamp;
  final bool isMe;
  final bool isDelivered;

  ChatMessage({
    this.id,
    required this.sender,
    required this.message,
    required this.originalTimestamp,
    required this.isMe,
    this.isDelivered = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'message': message,
      'timestamp': originalTimestamp.millisecondsSinceEpoch,
      'is_me': isMe ? 1 : 0,
      'is_delivered': isDelivered ? 1 : 0,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int?,
      sender: map['sender'] as String? ?? '',
      message: map['message'] as String? ?? '',
      originalTimestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isMe: (map['is_me'] as int? ?? 0) == 1,
      isDelivered: (map['is_delivered'] as int? ?? 0) == 1,
    );
  }
}
