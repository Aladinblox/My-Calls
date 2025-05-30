const express = require('express');
const router = express.Router();
const keyBundleController = require('../controllers/keyBundleController');
const authMiddleware = require('../middleware/authMiddleware');

// @route   POST api/keys/publish
// @desc    Publish E2EE key bundle
// @access  Private
router.post('/publish', authMiddleware, keyBundleController.publishKeys);

// @route   GET api/keys/:userId/bundle
// @desc    Get E2EE key bundle for a user
// @access  Private
router.get('/:userId/bundle', authMiddleware, keyBundleController.getKeyBundle);

// @route   GET api/keys/onetime/count (Changed to GET for simplicity as it's fetching a count)
// @desc    Get current count of one-time pre-keys for the authenticated user
// @access  Private
router.get('/onetime/count', authMiddleware, keyBundleController.getOneTimePreKeyCount);

// @route   POST api/keys/onetime/replenish
// @desc    Add more one-time pre-keys for the authenticated user
// @access  Private
router.post('/onetime/replenish', authMiddleware, keyBundleController.replenishOneTimePreKeys);


module.exports = router;
