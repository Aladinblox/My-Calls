// Corresponds to the backend Message model

class Message {
  final String id; // MongoDB _id
  final String conversationId;
  final String senderId; // User ID of the sender
  final String receiverId; // User ID of the receiver
  final String messageType; // 'text', 'image', etc.
  final String content;
  final DateTime timestamp;
  final bool read;
  final String? senderUsername; // Optional: for display

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    this.messageType = 'text',
    required this.content,
    required this.timestamp,
    this.read = false,
    this.senderUsername,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] as String,
      conversationId: json['conversationId'] as String,
      // Handle populated senderId which might be an object
      senderId: json['senderId'] is String ? json['senderId'] as String : (json['senderId']?['_id'] as String? ?? 'unknown_sender'),
      receiverId: json['receiverId'] is String ? json['receiverId'] as String : (json['receiverId']?['_id'] as String? ?? 'unknown_receiver'),
      messageType: json['messageType'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
      senderUsername: json['senderId'] is Map ? json['senderId']['username'] as String? : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'messageType': messageType,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
    };
  }
}
