const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const authMiddleware = require('../middleware/authMiddleware'); // Assuming you have or will create this

// @route   POST api/chat/send
// @desc    Send a new message
// @access  Private
router.post('/send', authMiddleware, chatController.sendMessage);

// @route   GET api/chat/conversations
// @desc    Get all conversations for the current user
// @access  Private
router.get('/conversations', authMiddleware, chatController.getConversations);

// @route   GET api/chat/messages/:userId
// @desc    Get messages for a conversation with a specific user
// @access  Private
// Note: ':userId' here refers to the other participant in the conversation.
router.get('/messages/:userId', authMiddleware, chatController.getMessages);

module.exports = router;
