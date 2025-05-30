const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');

// @route   GET api/users/:userId/profile
// @desc    Get a user's public profile information
// @access  Private (requires authentication to access any user's profile)
router.get('/:userId/profile', authMiddleware, userController.getUserProfile);

// @route   POST api/users/presence
// @desc    Get presence status for a list of users
// @access  Private
router.post('/presence', authMiddleware, userController.getUsersPresence);

module.exports = router;
