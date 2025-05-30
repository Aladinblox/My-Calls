const mongoose = require('mongoose');

const conversationSchema = new mongoose.Schema({
  participants: [{ // Array of User ObjectIds
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  }],
  lastMessage: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    optional: true,
  },
  lastMessageTimestamp: {
    type: Date,
    default: Date.now,
    index: true, // Important for sorting conversations
  },
  // You could add other fields like unreadMessageCount for each participant later
  // e.g., unreadCounts: [{ userId: ObjectId, count: Number }]
}, {
  timestamps: true, // Adds createdAt and updatedAt automatically
});

// Ensure unique conversations for a set of participants to avoid duplicates
// This is a bit tricky for an array of participants.
// A compound index on participants array might not work as expected for uniqueness across orders.
// Application logic should handle finding existing conversations carefully.
// For two participants, a common approach is to always store them in a sorted order (e.g., by ObjectId string)
// and then create a unique compound index on participants[0] and participants[1].
// However, for this task, we'll rely on application logic to find/create.

// Method to update lastMessageTimestamp whenever a conversation is saved.
// This is useful if you update a conversation for other reasons than just a new message.
conversationSchema.pre('save', function(next) {
  if (this.isModified('lastMessage') || this.isNew) {
    this.lastMessageTimestamp = Date.now();
  }
  next();
});


const Conversation = mongoose.model('Conversation', conversationSchema);

module.exports = Conversation;
