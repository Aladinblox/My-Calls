const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  conversationId: {
    type: mongoose.Schema.Types.ObjectId, // Changed from String to ObjectId for consistency if it refers to Conversation._id
    ref: 'Conversation', // Assuming it refers to the Conversation model's _id
    required: true,
    index: true,
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  receiverId: { // Still useful to know direct recipient even with conversationId
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  messageType: {
    type: String,
    default: 'text', // e.g., 'text', 'image', 'file'
  },
  content: {
    type: String,
    required: function() { return this.messageType === 'text'; }, // Required if type is text
    trim: true,
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true,
  },
  read: { // For read receipts
    type: Boolean,
    default: false,
  },
  // Add other fields if needed, e.g., for image URLs, file info for other messageTypes
});

const Message = mongoose.model('Message', messageSchema);

module.exports = Message;
