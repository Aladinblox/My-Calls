const User = require('../models/User');
const Message = require('../models/Message');
const Conversation = require('../models/Conversation');
const { getSocketServerInstance } = require('../websocketManager'); // We'll create this simple module
const WebSocket = require('ws'); // Required for readyState check

// Send a new message
exports.sendMessage = async (req, res) => {
  const { receiverId, content, messageType = 'text' } = req.body;
  const senderId = req.user.id; // From authMiddleware

  if (!receiverId || !content) {
    return res.status(400).json({ message: 'Receiver ID and content are required.' });
  }

  if (senderId === receiverId) {
    return res.status(400).json({ message: 'Cannot send message to yourself.' });
  }

  try {
    // Find or create a conversation
    // Participants stored in a sorted manner to ensure uniqueness regardless of who initiated
    const participants = [senderId, receiverId].sort();
    let conversation = await Conversation.findOneAndUpdate(
      { participants: participants },
      { 
        participants: participants,
        $setOnInsert: { createdAt: new Date() } // Set initial createdAt if new
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    // Create new message
    const newMessage = new Message({
      conversationId: conversation._id,
      senderId,
      receiverId,
      messageType,
      content,
    });
    await newMessage.save();

    // Update conversation with last message
    conversation.lastMessage = newMessage._id;
    conversation.lastMessageTimestamp = newMessage.timestamp;
    await conversation.save();
    
    const populatedMessage = await Message.findById(newMessage._id)
        .populate('senderId', 'username displayName phoneNumber _id') // Added displayName
        .populate('receiverId', 'username displayName phoneNumber _id') // Added displayName
        .exec();


    // Real-time: Send message via WebSocket to receiver if connected
    const wssInstance = getSocketServerInstance();
    if (wssInstance && wssInstance.userConnections) { // userConnections is the Map from server.js
      const receiverSocket = wssInstance.userConnections.get(receiverId.toString());
      if (receiverSocket && receiverSocket.readyState === WebSocket.OPEN) {
        receiverSocket.send(JSON.stringify({
          type: 'new-message',
          payload: populatedMessage, // Send the full message object
        }));
        console.log(`Sent new message to receiver ${receiverId} via WebSocket.`);
      } else {
        console.log(`Receiver ${receiverId} not connected via WebSocket or connection not open.`);
      }
    } else {
        console.log("WebSocket server instance or userConnections not available.");
    }

    res.status(201).json(populatedMessage);

  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ message: 'Server error while sending message.', error: error.message });
  }
};

// Get all conversations for the current user
exports.getConversations = async (req, res) => {
  const userId = req.user.id;
  try {
    const conversations = await Conversation.find({ participants: userId })
      .populate({
        path: 'participants',
        select: 'username displayName phoneNumber _id profilePicture', // Added displayName
        match: { _id: { $ne: userId } } // Exclude self from populated participants array
      })
      .populate({
        path: 'lastMessage',
        select: 'content senderId timestamp messageType read',
        populate: { path: 'senderId', select: 'username displayName _id' } // Added displayName
      })
      .sort({ lastMessageTimestamp: -1 });
    
    // The above population of 'participants' will result in an array with one user (the other participant).
    // For cleaner output, one might want to transform this.
    const formattedConversations = conversations.map(conv => {
        const otherParticipant = conv.participants[0]; // Since we excluded self
        return {
            _id: conv._id,
            participants: [otherParticipant], // Keep it as an array for consistency or flatten
            lastMessage: conv.lastMessage,
            lastMessageTimestamp: conv.lastMessageTimestamp,
            createdAt: conv.createdAt,
            updatedAt: conv.updatedAt,
            // otherParticipant: otherParticipant // Alternative flat structure
        };
    });


    res.json(formattedConversations);
  } catch (error) {
    console.error('Error fetching conversations:', error);
    res.status(500).json({ message: 'Server error while fetching conversations.', error: error.message });
  }
};

// Get messages for a conversation with a specific user
exports.getMessages = async (req, res) => {
  const currentUserId = req.user.id;
  const otherUserId = req.params.userId;
  const { limit = 30, offset = 0 } = req.query; // Pagination

  if (!otherUserId) {
    return res.status(400).json({ message: 'Target user ID is required.'});
  }

  try {
    // Find the conversation
    const participants = [currentUserId, otherUserId].sort();
    const conversation = await Conversation.findOne({ participants: participants });

    if (!conversation) {
      return res.status(404).json({ messages: [], message: 'No conversation found with this user.' });
    }

    const messages = await Message.find({ conversationId: conversation._id })
      .populate('senderId', 'username displayName _id') // Added displayName
      .sort({ timestamp: -1 }) // Get newest messages first for typical chat view (then reverse on client or scroll up)
      .limit(parseInt(limit))
      .skip(parseInt(offset));
      // .sort({ timestamp: 1 }) // if you prefer oldest first and append new ones at bottom

    res.json(messages.reverse()); // Reverse to get chronological order for display (oldest at top)
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ message: 'Server error while fetching messages.', error: error.message });
  }
};
