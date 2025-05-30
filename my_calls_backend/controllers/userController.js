const User = require('../models/User');

// Get user profile information
exports.getUserProfile = async (req, res) => {
  try {
    const userId = req.params.userId;
    // Fetch user by ID and select only the necessary fields
    // Exclude sensitive information like hashedPassword and E2EE keys explicitly
    const userProfile = await User.findById(userId).select(
      '_id username displayName phoneNumber createdAt' // Add profilePictureUrl later if implemented
    );

    if (!userProfile) {
      return res.status(404).json({ message: 'User not found.' });
    }

    res.json(userProfile);
  } catch (error) {
    console.error('Error fetching user profile:', error);
    // Check for CastError (invalid ObjectId format)
    if (error.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid user ID format.' });
    }
    res.status(500).json({ message: 'Server error while fetching user profile.' });
  }
};

// Get presence status for a list of user IDs
exports.getUsersPresence = async (req, res) => {
  const { userIds } = req.body;

  if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
    return res.status(400).json({ message: 'userIds array is required.' });
  }

  try {
    // Ensure userIds are valid ObjectIds to prevent CastError if needed, or handle error.
    // For simplicity, assuming valid IDs are passed or DB handles malformed ones gracefully (though it might throw).
    const presenceData = await User.find({
      '_id': { $in: userIds }
    }).select('_id presenceStatus lastSeen'); // Select only relevant fields

    // Map to a more convenient structure if needed, e.g., a dictionary by userId
    const presenceMap = presenceData.reduce((map, user) => {
      map[user._id] = {
        status: user.presenceStatus,
        lastSeen: user.lastSeen,
      };
      return map;
    }, {});

    res.json(presenceMap); // Or return as array: res.json(presenceData);

  } catch (error) {
    console.error('Error fetching users presence:', error);
    res.status(500).json({ message: 'Server error while fetching users presence.' });
  }
};
