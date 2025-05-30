import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_calls_app/core/models/conversation.dart';
import 'package:my_calls_app/core/models/message.dart' as app_message;
import 'package:my_calls_app/core/services/signaling_service.dart';
import 'package:my_calls_app/core/services/e2ee_service.dart';
import 'package:my_calls_app/core/providers/auth_provider.dart'; // Import AuthProvider
// import 'package:my_calls_app/core/providers/call_provider.dart'; // MOCK_TOKEN was here

const String _API_URL_BASE = "http://localhost:3000/api"; // TODO: Centralize config

class ChatProvider with ChangeNotifier {
  final SignalingService _signalingService;
  final E2eeService _e2eeService;
  AuthProvider? _authProvider; // To access token and user ID

  List<Conversation> _conversations = [];
  final Map<String, LinkedHashMap<String, app_message.Message>> _messagesByConversation = {};
  final Map<String, String> _decryptedMessageContentCache = {};

  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  String? _activeConversationTargetUserId;

  // String? _authToken; // Replaced by _authProvider.token
  // String? _selfId; // Replaced by _authProvider.currentUser.id

  UnmodifiableListView<Conversation> get conversations => UnmodifiableListView(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;


  ChatProvider(this._signalingService, this._e2eeService, AuthProvider? authProvider) : _authProvider = authProvider {
    _signalingService.onNewMessage = _handleNewMessage;
    if (_authProvider?.isAuthenticated == true) {
      _initializeUserSpecificData();
    }
  }

  void updateAuthProvider(AuthProvider authProvider) {
    bool wasAuthenticated = _authProvider?.isAuthenticated ?? false;
    _authProvider = authProvider;
    if (_authProvider?.isAuthenticated == true && !wasAuthenticated) {
      _initializeUserSpecificData();
    } else if (_authProvider?.isAuthenticated == false && wasAuthenticated) {
      clearChatData(); // Clear data on logout
    }
  }

  Future<void> _initializeUserSpecificData() async {
    if (_authProvider?.isAuthenticated != true) return;
    // Pass auth token to E2eeService if it needs it for API calls
    _e2eeService.setAuthToken(_authProvider!.token); 
    await _e2eeService.initialize();
    await fetchConversations();
  }

  void setActiveConversationTargetUserId(String? userId) {
    _activeConversationTargetUserId = userId;
    debugPrint("ChatProvider: Active conversation target user ID set to: $userId");
  }

  UnmodifiableListView<app_message.Message> messagesForConversation(String targetUserId) {
    // Conversation ID is constructed by sorting two user IDs and joining them or using the ID from Conversation object
    // For simplicity here, we'll use targetUserId as a proxy key, assuming one-on-one chats.
    // A more robust way is to find the conversation object and use its actual ID.
    final conversation = _findConversationWithUser(targetUserId);
    if (conversation == null) return UnmodifiableListView([]);

    final messagesMap = _messagesByConversation[conversation.id] ?? LinkedHashMap();
    // Map messages to potentially include decrypted content
    final displayMessages = messagesMap.values.map((msg) {
      if (msg.messageType.startsWith('signal/') && _decryptedMessageContentCache.containsKey(msg.id)) {
        // Create a new message instance or a wrapper with the decrypted content
        return app_message.Message(
          id: msg.id,
          conversationId: msg.conversationId,
          senderId: msg.senderId,
          receiverId: msg.receiverId,
          content: _decryptedMessageContentCache[msg.id]!, // Use decrypted content
          timestamp: msg.timestamp,
          messageType: 'text/decrypted', // Indicate it's decrypted text
          read: msg.read,
          senderUsername: msg.senderUsername,
        );
      }
      return msg;
    }).toList();
    return UnmodifiableListView(displayMessages);
  }

  Conversation? _findConversationWithUser(String userId) {
     try {
      return _conversations.firstWhere(
          (c) => c.participants.any((p) => p.id == userId));
    } catch (e) {
      return null; // Not found
    }
  }


  Future<void> fetchConversations() async {
    if (_authProvider?.isAuthenticated != true) return;
    if (_isLoadingConversations) return;
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_API_URL_BASE/chat/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _authProvider!.token!,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = jsonDecode(response.body);
        _conversations = decodedData.map((data) => Conversation.fromJson(data)).toList();
        debugPrint("ChatProvider: Fetched ${_conversations.length} conversations.");
      } else {
        debugPrint('ChatProvider: Failed to load conversations: ${response.statusCode} ${response.body}');
        // Handle error (e.g., show a message to the user)
      }
    } catch (e) {
      debugPrint('ChatProvider: Error fetching conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> fetchMessages(String targetUserId) async {
    _isLoadingMessages = true;
    notifyListeners();

    final conversation = _findConversationWithUser(targetUserId);
    String? conversationIdForMapKey = conversation?.id;

    if (conversationIdForMapKey == null) {
        // Attempt to find/create on backend if local not found, or handle error
        debugPrint("ChatProvider: No local conversation found for $targetUserId to fetch messages. The API will try to find/create.");
    }


    if (_authProvider?.isAuthenticated != true) return;
    _isLoadingMessages = true;
    notifyListeners();

    final conversation = _findConversationWithUser(targetUserId);
    String? conversationIdForMapKey = conversation?.id;

    if (conversationIdForMapKey == null) {
        debugPrint("ChatProvider: No local conversation found for $targetUserId to fetch messages. The API will try to find/create.");
    }

    try {
      final response = await http.get(
        Uri.parse('$_API_URL_BASE/chat/messages/$targetUserId'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _authProvider!.token!,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> decodedData = jsonDecode(response.body);
        final rawMessages = decodedData.map((data) => app_message.Message.fromJson(data)).toList();
        
        final LinkedHashMap<String, app_message.Message> messagesMap = LinkedHashMap();
        for (var msg in rawMessages) {
          if (msg.messageType.startsWith('signal/')) { // Encrypted message
            final currentUserId = _authProvider!.currentUser!.id;
            String partnerId = msg.senderId == currentUserId ? msg.receiverId : msg.senderId;
            
            // For this example, let's assume messageType "signal/prekey" means type 3, "signal/message" means type 1.
            // This is a simplification. The actual type is part of the encrypted payload usually.
            int ciphertextType = msg.messageType == 'signal/prekey' ? 3 : 1; // Placeholder

            final decryptedContent = await _e2eeService.decryptMessage(partnerId, msg.content, ciphertextType);
            if (decryptedContent != null) {
              _decryptedMessageContentCache[msg.id] = decryptedContent;
               messagesMap[msg.id] = app_message.Message(
                  id: msg.id, conversationId: msg.conversationId, senderId: msg.senderId, receiverId: msg.receiverId,
                  content: decryptedContent, timestamp: msg.timestamp, messageType: 'text/decrypted', read: msg.read, senderUsername: msg.senderUsername
              );
            } else {
              // Store original encrypted message or placeholder if decryption fails
              _decryptedMessageContentCache[msg.id] = "[Decryption Failed]";
               messagesMap[msg.id] = msg; // Store original or a modified one indicating error
            }
          } else { // Plain text message
            messagesMap[msg.id] = msg;
          }
        }
        
        if (conversationIdForMapKey == null && rawMessages.isNotEmpty) {
            conversationIdForMapKey = rawMessages.first.conversationId;
        }

        if (conversationIdForMapKey != null) {
            _messagesByConversation[conversationIdForMapKey] = messagesMap;
            debugPrint("ChatProvider: Fetched and processed ${rawMessages.length} messages for conversation with $targetUserId (convId: $conversationIdForMapKey).");
        } else if (rawMessages.isEmpty && response.statusCode == 200) {
            debugPrint("ChatProvider: No messages found for $targetUserId, conversation might be new.");
             if (conversation != null) {
                _messagesByConversation[conversation.id] = LinkedHashMap();
            }
        }

      } else if (response.statusCode == 404) {
         debugPrint("ChatProvider: No conversation or messages found for $targetUserId (404).");
         if (conversationIdForMapKey != null) {
            _messagesByConversation[conversationIdForMapKey] = LinkedHashMap();
         }
      }
      else {
        debugPrint('ChatProvider: Failed to load messages for $targetUserId: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('ChatProvider: Error fetching messages for $targetUserId: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String targetUserId, String plainTextContent) async {
    if (_authProvider?.isAuthenticated != true) {
      debugPrint("ChatProvider: User not authenticated. Cannot send message.");
      return;
    }
    if (plainTextContent.trim().isEmpty) return;

    final encryptedPayload = await _e2eeService.encryptMessage(targetUserId, plainTextContent);
    if (encryptedPayload == null) {
      debugPrint("ChatProvider: Encryption failed. Message not sent.");
      // TODO: Show error to user
      return;
    }

    final String ciphertext = encryptedPayload['ciphertext'] as String;
    // Determine messageType based on Signal's ciphertext type
    // This is a simplification. The backend might just store the ciphertext and type.
    final int signalCiphertextType = encryptedPayload['type'] as int;
    final String messageTypeForBackend = signalCiphertextType == 3 ? 'signal/prekey' : 'signal/message'; // Example mapping

    try {
      final response = await http.post(
        Uri.parse('$_API_URL_BASE/chat/send'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _authProvider!.token!,
        },
        body: jsonEncode({
          'receiverId': targetUserId,
          'content': ciphertext, // Send ciphertext
          'messageType': messageTypeForBackend, // Send new messageType
        }),
      );

      if (response.statusCode == 201) {
        final newMessageJson = jsonDecode(response.body);
        // The message from backend has ciphertext. We add it to local cache.
        // For display, we'll use the original plaintext for the sender.
        var sentMessage = app_message.Message.fromJson(newMessageJson);
        
        // Store the decrypted (original plaintext) for sender's display
        _decryptedMessageContentCache[sentMessage.id] = plainTextContent;
        _addMessageToLocalCache(app_message.Message(
          id: sentMessage.id, conversationId: sentMessage.conversationId, senderId: sentMessage.senderId,
          receiverId: sentMessage.receiverId, content: plainTextContent, // Show plaintext for sender
          timestamp: sentMessage.timestamp, messageType: 'text/decrypted', // Mark as decrypted for UI
          read: sentMessage.read, senderUsername: sentMessage.senderUsername
        ));
        
        await fetchConversations();
        notifyListeners();
      } else {
        debugPrint('ChatProvider: Failed to send message: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('ChatProvider: Error sending message: $e');
    }
  }

  Future<void> _handleNewMessage(Map<String, dynamic> messagePayload) async {
    if (_authProvider?.isAuthenticated != true) return; // Ignore if not authenticated

    final incomingMessage = app_message.Message.fromJson(messagePayload);
    debugPrint("ChatProvider: Received new message via WebSocket: ID ${incomingMessage.id} from ${incomingMessage.senderId}");
    
    // Ensure message is not from self (backend should ideally not send self-messages via WS, but good to check)
    if (incomingMessage.senderId == _authProvider!.currentUser!.id) {
        debugPrint("ChatProvider: Received own message via WebSocket, likely echo or misconfiguration. Ignoring.");
        return;
    }

    if (incomingMessage.messageType.startsWith('signal/')) {
      int ciphertextType = incomingMessage.messageType == 'signal/prekey' ? 3 : 1; // Placeholder

      final decryptedContent = await _e2eeService.decryptMessage(
        incomingMessage.senderId, // This is the partnerId for decryption
        incomingMessage.content, 
        ciphertextType
      );

      if (decryptedContent != null) {
        _decryptedMessageContentCache[incomingMessage.id] = decryptedContent;
         _addMessageToLocalCache(app_message.Message(
            id: incomingMessage.id, conversationId: incomingMessage.conversationId, senderId: incomingMessage.senderId,
            receiverId: incomingMessage.receiverId, content: decryptedContent, timestamp: incomingMessage.timestamp,
            messageType: 'text/decrypted', read: incomingMessage.read, senderUsername: incomingMessage.senderUsername
        ));
      } else {
        debugPrint("ChatProvider: Decryption failed for message ID ${incomingMessage.id}");
        _decryptedMessageContentCache[incomingMessage.id] = "[Decryption Failed]";
        _addMessageToLocalCache(incomingMessage); // Add original encrypted message
      }
    } else { // Plain text message (should not happen if E2EE is enforced)
      _addMessageToLocalCache(incomingMessage);
    }

    fetchConversations();
    notifyListeners();
  }

  void _addMessageToLocalCache(app_message.Message message) {
    final conversationId = message.conversationId;
    // Ensure LinkedHashMap for conversation messages
    _messagesByConversation.putIfAbsent(conversationId, () => LinkedHashMap<String, app_message.Message>());
    _messagesByConversation[conversationId]![message.id] = message;
  }

  // Call this when user logs out or provider is disposed
  void clearChatData() {
    _conversations.clear();
    _messagesByConversation.clear();
    _activeConversationTargetUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    // _signalingService.onNewMessage = null; // Important to clear callback if SignalingService persists longer
    super.dispose();
  }
}
