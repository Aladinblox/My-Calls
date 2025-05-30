class UserModel {
  final String id;
  final String? username; // Optional, might be same as phoneNumber or unique
  final String? displayName;
  final String phoneNumber;
  // Add other fields like profilePictureUrl, etc. as needed

  UserModel({
    required this.id,
    this.username,
    this.displayName,
    required this.phoneNumber,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['userId'] as String? ?? json['_id'] as String, // Handle both _id and userId from backend responses
      username: json['username'] as String?,
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '', // Ensure phoneNumber is not null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id, // or '_id' depending on backend expectation for sending
      'username': username,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
    };
  }

  // Helper to get the best available name for display
  String get bestDisplayName {
    return displayName ?? username ?? phoneNumber;
  }
}
