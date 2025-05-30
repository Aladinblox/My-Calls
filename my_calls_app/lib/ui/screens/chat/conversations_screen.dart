import 'package:flutter/material.dart';
import 'package:my_calls_app/core/models/conversation.dart';
import 'package:my_calls_app/core/providers/chat_provider.dart';
import 'package:my_calls_app/core/providers/presence_provider.dart'; // Import PresenceProvider
import 'package:my_calls_app/ui/screens/chat/chat_screen.dart';
import 'package:my_calls_app/ui/widgets/presence_indicator_widget.dart'; // Will create this
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch conversations when the screen is initialized
    // Provider.of<ChatProvider>(context, listen: false).fetchConversations();
    // Already called in ChatProvider constructor, but can be made explicit here if needed for refresh logic.
  }

  Future<void> _startNewConversation() async {
    final targetUserIdController = TextEditingController();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);

    String? targetUserId = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Conversation'),
          content: TextField(
            controller: targetUserIdController,
            decoration: const InputDecoration(hintText: "Enter Target User ID"),
            autofocus: true,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Start Chat'),
              onPressed: () {
                Navigator.of(context).pop(targetUserIdController.text.trim());
              },
            ),
          ],
        );
      },
    );

    if (targetUserId != null && targetUserId.isNotEmpty) {
      // Navigate to chat screen, ChatProvider will handle finding/creating conversation
      chatProvider.setActiveConversationTargetUserId(targetUserId); // Important for fetchMessages
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(targetUserId: targetUserId),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<ChatProvider>(context, listen: false).fetchConversations();
            },
          )
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoadingConversations && chatProvider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (chatProvider.conversations.isEmpty) {
            return const Center(
              child: Text(
                'No conversations yet.\nTap the + button to start a new chat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => chatProvider.fetchConversations(),
            child: ListView.separated(
              itemCount: chatProvider.conversations.length,
              itemBuilder: (context, index) {
                final conversation = chatProvider.conversations[index];
                final presenceProvider = Provider.of<PresenceProvider>(context); // No listen needed for just getting data once
                final conversation = chatProvider.conversations[index];
                final otherParticipant = conversation.otherParticipant;
                final lastMessage = conversation.lastMessage;
                final userPresence = otherParticipant != null ? presenceProvider.getPresence(otherParticipant.id) : null;

                String title = otherParticipant?.bestDisplayName ?? 'Unknown User';
                String subtitle = lastMessage?.content ?? 'No messages yet';
                if (lastMessage?.messageType == 'text/decrypted' && lastMessage?.content == "[Decryption Failed]") {
                    subtitle = '🔒 Message decryption failed';
                } else if (lastMessage?.messageType == 'text/decrypted') {
                    subtitle = '🔒 ${lastMessage?.content}'; // Show lock for decrypted messages
                } else if (lastMessage?.messageType?.startsWith('signal/') == true) {
                    subtitle = '🔒 Encrypted message'; // Placeholder if content is ciphertext
                } else if (lastMessage?.messageType == 'image') {
                    subtitle = '📷 Image';
                } else if (lastMessage?.messageType == 'file') {
                    subtitle = '📄 File';
                }
                
                // Show sender for group chats, or if last message was from self
                // For one-on-one, if last message is from self, you might want to indicate that.
                // For now, assuming one-on-one and showing content directly.

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        child: Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      if (userPresence != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: PresenceIndicatorWidget(status: userPresence.status, size: 15),
                        ),
                    ],
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Text(
                    lastMessage != null
                        ? DateFormat('MMM d, hh:mm a').format(lastMessage.timestamp.toLocal())
                        : '',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                  onTap: () {
                    if (otherParticipant != null) {
                       chatProvider.setActiveConversationTargetUserId(otherParticipant.id);
                       Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            targetUserId: otherParticipant.id,
                            targetUserDisplayName: title, // Pass display name
                          ),
                        ),
                      );
                    }
                  },
                );
              },
              separatorBuilder: (context, index) => Divider(height: 0.5, indent: 72, endIndent: 16, color: Colors.grey[300]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startNewConversation,
        tooltip: 'New Conversation',
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}
