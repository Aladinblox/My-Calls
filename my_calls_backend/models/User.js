const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  username: { // Optional, could be used for display or if phone number is not unique for some reason
    type: String,
    required: false, 
    unique: true,
    sparse: true, // Allows multiple documents to have a null username if it's not provided
    trim: true,
  },
  displayName: { // User's preferred display name
    type: String,
    trim: true,
    maxLength: 50,
  },
  phoneNumber: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    // Add validation for phone number format if necessary
  },
  hashedPassword: {
    type: String,
    required: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },

  // E2EE Fields for Signal Protocol
  identityKey: { // Public identity key (hex encoded)
    type: String,
    trim: true,
  },
  registrationId: { // Device registration ID
    type: Number, 
  },
  signedPreKey: { // Signed pre-key an object
    keyId: Number,
    publicKey: String, // hex encoded
    signature: String, // hex encoded
  },
  oneTimePreKeys: [{ // Batch of one-time pre-keys
    keyId: Number,
    publicKey: String, // hex encoded
  }],

  // Presence Fields
  presenceStatus: {
    type: String,
    enum: ['online', 'idle', 'offline'], // Define possible statuses
    default: 'offline',
  },
  lastSeen: {
    type: Date,
    default: Date.now,
  },
});

// Pre-save hook to hash password before saving a new user
userSchema.pre('save', async function (next) {
  if (!this.isModified('hashedPassword')) {
    return next();
  }
  try {
    const salt = await bcrypt.genSalt(10);
    this.hashedPassword = await bcrypt.hash(this.hashedPassword, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Method to compare candidate password with the hashed password
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.hashedPassword);
};

// Update `updatedAt` field before saving
userSchema.pre('save', function (next) {
  this.updatedAt = Date.now();
  next();
});

const User = mongoose.model('User', userSchema);

module.exports = User;
