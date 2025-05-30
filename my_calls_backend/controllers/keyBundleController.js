const User = require('../models/User');

// Publish E2EE key bundle
exports.publishKeys = async (req, res) => {
  const { identityKey, registrationId, signedPreKey, oneTimePreKeys } = req.body;
  const userId = req.user.id; // From authMiddleware

  // Basic validation
  if (!identityKey || registrationId === undefined || !signedPreKey || !signedPreKey.keyId || !signedPreKey.publicKey || !signedPreKey.signature) {
    return res.status(400).json({ message: 'Missing required key bundle components.' });
  }
  if (oneTimePreKeys && !Array.isArray(oneTimePreKeys)) {
    return res.status(400).json({ message: 'oneTimePreKeys must be an array.' });
  }

  try {
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found.' });
    }

    user.identityKey = identityKey;
    user.registrationId = registrationId;
    user.signedPreKey = {
        keyId: signedPreKey.keyId,
        publicKey: signedPreKey.publicKey,
        signature: signedPreKey.signature,
    };

    if (oneTimePreKeys && oneTimePreKeys.length > 0) {
      // Simple replacement for this example. A more robust solution might merge or check for duplicates.
      // Or, if replenishing, ensure they are truly new keys.
      // For now, we'll append, but client should manage sending only new ones to avoid excessive growth if not consumed.
      // A better approach for replenishment would be a separate endpoint or logic to ensure atomicity.
      user.oneTimePreKeys.push(...oneTimePreKeys.map(k => ({ keyId: k.keyId, publicKey: k.publicKey })));
    }
    
    await user.save();
    res.status(200).json({ message: 'Key bundle published successfully.' });

  } catch (error) {
    console.error('Error publishing keys:', error);
    res.status(500).json({ message: 'Server error while publishing keys.', error: error.message });
  }
};

// Get E2EE key bundle for a user
exports.getKeyBundle = async (req, res) => {
  const requestedUserId = req.params.userId;

  try {
    const user = await User.findById(requestedUserId);
    if (!user || !user.identityKey || !user.signedPreKey) { // Check if user has published keys
      return res.status(404).json({ message: 'Key bundle not found for this user or incomplete.' });
    }

    // Get one oneTimePreKey and remove it from the list (atomically if possible, though harder with array pop)
    // For simplicity, we'll take the first one.
    // In a high-concurrency environment, this is a race condition.
    // A more robust system might use a separate collection for prekeys or a DB transaction.
    let oneTimeKey = null;
    if (user.oneTimePreKeys && user.oneTimePreKeys.length > 0) {
      // To "remove" it, we'll pull it from the array. This is not perfectly atomic.
      // A better way is to mark as "claimed" or move to a different field/collection.
      // For this example, we modify and save.
      oneTimeKey = user.oneTimePreKeys.shift(); // Takes the first, modifies array
      await User.findByIdAndUpdate(requestedUserId, { $pop: { oneTimePreKeys: -1 } }); // Actually remove the first element
      // Note: $pop with -1 removes the first element. $pop with 1 removes the last.
      // This ensures the key is (mostly) not reused.
      // If the save fails after sending response, key might be reused or lost. True atomicity is hard here.
    } else {
        console.warn(`User ${requestedUserId} has no oneTimePreKeys available.`);
    }
    
    res.status(200).json({
      userId: user._id, // For client to confirm
      identityKey: user.identityKey,
      registrationId: user.registrationId,
      signedPreKey: user.signedPreKey,
      oneTimePreKey: oneTimeKey, // This might be null if none are available
    });

  } catch (error) {
    console.error('Error fetching key bundle:', error);
    res.status(500).json({ message: 'Server error while fetching key bundle.', error: error.message });
  }
};

// Get current count of one-time pre-keys
exports.getOneTimePreKeyCount = async (req, res) => {
    const userId = req.user.id;
    try {
        const user = await User.findById(userId).select('oneTimePreKeys');
        if (!user) {
            return res.status(404).json({ message: 'User not found.' });
        }
        res.status(200).json({ count: user.oneTimePreKeys ? user.oneTimePreKeys.length : 0 });
    } catch (error) {
        console.error('Error getting oneTimePreKey count:', error);
        res.status(500).json({ message: 'Server error.', error: error.message });
    }
};

// Replenish one-time pre-keys
exports.replenishOneTimePreKeys = async (req, res) => {
    const { oneTimePreKeys } = req.body;
    const userId = req.user.id;

    if (!oneTimePreKeys || !Array.isArray(oneTimePreKeys) || oneTimePreKeys.length === 0) {
        return res.status(400).json({ message: 'oneTimePreKeys array is required and must not be empty.' });
    }

    try {
        // Validate each key object
        for (const key of oneTimePreKeys) {
            if (key.keyId === undefined || !key.publicKey) {
                return res.status(400).json({ message: 'Each oneTimePreKey must have keyId and publicKey.' });
            }
        }
        
        // $push each element to the array
        const result = await User.findByIdAndUpdate(
            userId, 
            { $push: { oneTimePreKeys: { $each: oneTimePreKeys } } },
            { new: true } // Returns the updated document
        );

        if (!result) {
            return res.status(404).json({ message: 'User not found.' });
        }
        res.status(200).json({ message: 'One-time pre-keys replenished successfully.', count: result.oneTimePreKeys.length });
    } catch (error) {
        console.error('Error replenishing oneTimePreKeys:', error);
        res.status(500).json({ message: 'Server error.', error: error.message });
    }
};
