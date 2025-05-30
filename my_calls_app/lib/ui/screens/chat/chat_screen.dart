import 'package:flutter/material.dart';
import 'package:my_calls_app/core/models/message.dart' as app_message;
import 'package:my_calls_app/core/providers/auth_provider.dart';
import 'package:my_calls_app/core/providers/chat_provider.dart';
import 'package:my_calls_app/core/providers/presence_provider.dart'; // Import PresenceProvider
import 'package:my_calls_app/ui/widgets/presence_indicator_widget.dart'; // Import PresenceIndicatorWidget
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserDisplayName; // Added for AppBar title

  const ChatScreen({
    super.key,
    required this.targetUserId,
    required this.targetUserDisplayName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.setActiveConversationTargetUserId(widget.targetUserId);
    chatProvider.fetchMessages(widget.targetUserId);

    // Listen to message list changes to scroll down
    // A bit of a workaround; ideally, this logic is tied to when a new message is actually added.
    // Consider using a ValueListenable or specific callback from provider for new messages.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //      // This listener might be too broad, if any change in provider triggers it.
    //     Provider.of<ChatProvider>(context, listen: true).addListener(_scrollToBottomIfAtEnd);
    //   }
    // });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Provider.of<ChatProvider>(context, listen: false).removeListener(_scrollToBottomIfAtEnd);
    Provider.of<ChatProvider>(context, listen: false).setActiveConversationTargetUserId(null);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // void _scrollToBottomIfAtEnd() {
  //   // More complex logic to only scroll if user was already at the bottom or message is from self.
  //   // For simplicity now, new messages will trigger a scroll.
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //      if (mounted && _scrollController.hasClients) _scrollToBottom();
  //   });
  // }
  
  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      Provider.of<ChatProvider>(context, listen: false)
          .sendMessage(widget.targetUserId, content);
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context);
    final presenceProvider = Provider.of<PresenceProvider>(context); // Get PresenceProvider
    final messages = chatProvider.messagesForConversation(widget.targetUserId);
    final String currentUserId = authProvider.currentUser?.id ?? '';
    final userPresence = presenceProvider.getPresence(widget.targetUserId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && messages.isNotEmpty) _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            if (userPresence != null) // Show presence indicator before name
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: PresenceIndicatorWidget(status: userPresence.status, size: 12),
              ),
            Expanded(
              child: Text(
                widget.targetUserDisplayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () { /* TODO: Initiate voice call */ }),
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () { /* TODO: Initiate video call */ }),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: chatProvider.isLoadingMessages && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Say hi to ${widget.targetUserDisplayName}!',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final bool isSentByMe = message.senderId == currentUserId;
                          return _buildMessageBubble(context, message, isSentByMe);
                        },
                      ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, app_message.Message message, bool isSentByMe) {
    bool isDecryptionFailed = message.content == "[Decryption Failed]";
    bool isEncryptedPlaceholder = message.messageType.startsWith('signal/') && !isDecryptionFailed;

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isSentByMe 
              ? Theme.of(context).colorScheme.primary 
              : (isDecryptionFailed || isEncryptedPlaceholder ? Colors.orange[100] : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18.0),
            topRight: const Radius.circular(18.0),
            bottomLeft: isSentByMe ? const Radius.circular(18.0) : const Radius.circular(4.0),
            bottomRight: isSentByMe ? const Radius.circular(4.0) : const Radius.circular(18.0),
          ),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.07),
               blurRadius: 3,
               offset: const Offset(1, 2),
             )
           ],
        ),
        child: Column(
          crossAxisAlignment: isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isDecryptionFailed)
              Icon(Icons.lock_outline, color: Colors.red[700], size: 16),
            else if (isEncryptedPlaceholder || message.messageType == 'text/decrypted')
              Icon(Icons.lock_person_outlined, color: isSentByMe ? Colors.white70 : Colors.green[700], size: 14),
            
            Text(
              isEncryptedPlaceholder ? "🔒 Encrypted Message" : message.content,
              style: TextStyle(
                color: isSentByMe ? Colors.white : (isDecryptionFailed ? Colors.red[700] : Colors.black87), 
                fontSize: 16
              ),
            ),
            const SizedBox(height: 5.0),
            Text(
              DateFormat('hh:mm a').format(message.timestamp.toLocal()),
              style: TextStyle(
                color: isSentByMe ? Colors.white.withOpacity(0.8) : Colors.black54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 1,
            color: Colors.grey.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // IconButton(icon: Icon(Icons.add), onPressed: () { /* TODO: Attachments */ }),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none, // Remove border from TextField itself
                filled: false, // Let container handle fill
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              ),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            onPressed: _sendMessage,
            padding: const EdgeInsets.all(12.0),
          ),
        ],
      ),
    );
  }
}

// Helper to get current user ID - replace with actual AuthProvider logic
// String getCurrentUserId(BuildContext context) {
//   // Placeholder - In a real app, you'd get this from your AuthProvider
//   // For example: return Provider.of<AuthProvider>(context, listen: false).currentUser.id;
//   return "user_self_temp_id"; // Make sure this matches MOCK_SELF_ID if still used
// }
    );
  }
}
