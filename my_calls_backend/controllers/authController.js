const User = require('../models/User');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// Register a new user
exports.registerUser = async (req, res) => {
  const { username, displayName, phoneNumber, password } = req.body; // Added displayName

  try {
    // Check if user already exists (by phone number)
    let user = await User.findOne({ phoneNumber });
    if (user) {
      return res.status(400).json({ message: 'User already exists with this phone number' });
    }

    // If username is provided, check for its uniqueness
    if (username) {
      let userByUsername = await User.findOne({ username });
      if (userByUsername) {
        return res.status(400).json({ message: 'Username is already taken' });
      }
    }

    // Create new user instance
    user = new User({
      username,
      displayName, // Save displayName
      phoneNumber,
      hashedPassword: password, // Password will be hashed by pre-save hook in User.js
    });

    // Save user to database
    await user.save();

    // Create JWT Payload
    const payload = {
      user: {
        id: user.id, // Mongoose uses 'id' as a virtual getter for '_id'
      },
    };

    // Sign token
    jwt.sign(
      payload,
      process.env.JWT_SECRET,
      { expiresIn: '5h' }, // Token expires in 5 hours
      (err, token) => {
        if (err) throw err;
        res.status(201).json({ 
            token, 
            userId: user.id, 
            username: user.username,
            displayName: user.displayName,
            phoneNumber: user.phoneNumber,
            message: 'User registered successfully' 
        });
      }
    );
  } catch (error) {
    console.error('Error in user registration:', error.message);
    res.status(500).json({ message: 'Server error during registration', error: error.message });
  }
};

// Login an existing user
exports.loginUser = async (req, res) => {
  const { phoneNumber, password } = req.body;

  try {
    // Check if user exists
    const user = await User.findOne({ phoneNumber });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials (user not found)' });
    }

    // Compare password
    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials (password incorrect)' });
    }

    // Create JWT Payload
    const payload = {
      user: {
        id: user.id,
      },
    };

    // Sign token
    jwt.sign(
      payload,
      process.env.JWT_SECRET,
      { expiresIn: '5h' },
      (err, token) => {
        if (err) throw err;
        res.json({ 
            token, 
            userId: user.id, 
            username: user.username, 
            displayName: user.displayName, // Include displayName in login response
            phoneNumber: user.phoneNumber 
        });
      }
    );
  } catch (error) {
    console.error('Error in user login:', error.message);
    res.status(500).json({ message: 'Server error during login', error: error.message });
  }
};
