import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:my_calls_app/core/services/signaling_service.dart';
import 'package:my_calls_app/core/providers/auth_provider.dart'; // To get current user ID
import 'package:http/http.dart' as http; // For optional API endpoint
import 'dart:convert'; // For jsonDecode

// Using API URL from ChatProvider for now, TODO: Centralize config
const String _API_URL_BASE_PRESENCE = "http://localhost:3000/api/users"; 

class UserPresence {
  final String userId;
  final String status; // 'online', 'idle', 'offline'
  final DateTime? lastSeen;

  UserPresence({required this.userId, required this.status, this.lastSeen});

  factory UserPresence.fromJson(String userId, Map<String, dynamic> json) {
    return UserPresence(
      userId: userId,
      status: json['status'] as String? ?? 'offline',
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen'] as String) : null,
    );
  }
}

class PresenceProvider with ChangeNotifier {
  final SignalingService _signalingService;
  final AuthProvider _authProvider; // To get current user's token for API calls

  final Map<String, UserPresence> _presenceData = {};

  UnmodifiableMapView<String, UserPresence> get presenceData => UnmodifiableMapView(_presenceData);

  PresenceProvider(this._signalingService, this._authProvider) {
    _signalingService.onPresenceUpdate = _handlePresenceUpdate;
    _authProvider.addListener(_onAuthStateChanged);
    _initialize();
  }
  
  void _onAuthStateChanged() {
    if (!_authProvider.isAuthenticated) {
      _presenceData.clear(); // Clear presence data on logout
      notifyListeners();
    } else {
      _initialize(); // Re-initialize if user logs in (e.g. fetch initial presence for contacts)
    }
  }

  void _initialize() {
    // Optionally, fetch initial presence for a set of users (e.g., contacts) if API is available
    // This would typically be done after loading contacts.
    // For now, it will just rely on live updates.
    if (_authProvider.isAuthenticated) {
        debugPrint("PresenceProvider initialized.");
    }
  }

  void _handlePresenceUpdate(Map<String, dynamic> payload) {
    try {
      final userId = payload['userId'] as String?;
      final status = payload['status'] as String?;
      final lastSeenStr = payload['lastSeen'] as String?;

      if (userId == null || status == null) {
        debugPrint("PresenceProvider: Received presence update with missing userId or status.");
        return;
      }
      
      // Don't update self from broadcast if it might conflict with PresenceService's local determination
      // However, for simplicity, we can allow it, or add a check:
      // if (userId == _authProvider.currentUser?.id) return;


      final lastSeen = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;
      
      _presenceData[userId] = UserPresence(userId: userId, status: status, lastSeen: lastSeen);
      debugPrint("PresenceProvider: Updated presence for $userId to $status, lastSeen: $lastSeen");
      notifyListeners();
    } catch (e) {
      debugPrint("PresenceProvider: Error handling presence update: $e. Payload: $payload");
    }
  }

  UserPresence? getPresence(String userId) {
    return _presenceData[userId];
  }

  // Optional: Method to fetch initial presence for a list of users
  Future<void> fetchInitialPresence(List<String> userIds) async {
    if (!_authProvider.isAuthenticated || userIds.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_API_URL_BASE_PRESENCE/presence'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _authProvider.token!,
        },
        body: jsonEncode({'userIds': userIds}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = jsonDecode(response.body);
        decodedData.forEach((userId, presenceJson) {
          if (presenceJson is Map<String, dynamic>) {
             _presenceData[userId] = UserPresence.fromJson(userId, presenceJson);
          }
        });
        notifyListeners();
        debugPrint("PresenceProvider: Fetched initial presence for ${userIds.length} users.");
      } else {
        debugPrint('PresenceProvider: Failed to fetch initial presence: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('PresenceProvider: Error fetching initial presence: $e');
    }
  }
  
  @override
  void dispose() {
    _authProvider.removeListener(_onAuthStateChanged);
    // _signalingService.onPresenceUpdate = null; // Clear callback if SignalingService persists
    super.dispose();
  }
}
