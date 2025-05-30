import 'package:my_calls_app/core/models/message.dart';
import 'package:my_calls_app/core/models/user_model.dart'; // Assuming a simple user model for participant details

// Corresponds to the backend Conversation model (especially the formatted one from getConversations)
class Conversation {
  final String id; // MongoDB _id
  final List<ChatParticipant> participants; // Should contain the other participant(s)
  final Message? lastMessage;
  final DateTime lastMessageTimestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.lastMessageTimestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  // Helper getter to easily get the other participant in a one-on-one chat
  ChatParticipant? get otherParticipant {
    // Assumes 'participants' list from backend is already filtered to show only the other user.
    return participants.isNotEmpty ? participants.first : null;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    var participantsList = (json['participants'] as List<dynamic>? ?? [])
        .map((participantJson) => ChatParticipant.fromJson(participantJson as Map<String, dynamic>))
        .toList();

    return Conversation(
      id: json['_id'] as String,
      participants: participantsList,
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'] as Map<String, dynamic>)
          : null,
      lastMessageTimestamp: DateTime.parse(json['lastMessageTimestamp'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

// A simplified User model for chat participant details
// You might have a more comprehensive UserModel elsewhere
class ChatParticipant {
  final String id;
  final String? username;
  final String? displayName; // Added displayName
  final String? phoneNumber;
  // Add profilePictureUrl etc. if needed

  ChatParticipant({
    required this.id,
    this.username,
    this.displayName,
    this.phoneNumber,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: json['_id'] as String,
      username: json['username'] as String?,
      displayName: json['displayName'] as String?, // Parse displayName
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  // Updated getter to prioritize displayName
  String get bestDisplayName {
    return displayName ?? username ?? phoneNumber ?? id;
  }
}
