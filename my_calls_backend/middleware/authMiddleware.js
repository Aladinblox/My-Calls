const jwt = require('jsonwebtoken');
const User = require('../models/User'); // Adjust path if necessary

module.exports = async function(req, res, next) {
  // Get token from header
  const token = req.header('x-auth-token');

  // Check if not token
  if (!token) {
    return res.status(401).json({ message: 'No token, authorization denied' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Add user from payload to request object
    // Ensure the user exists in DB, though JWT validity should be primary check here
    // If token is valid, we trust its payload for userId for performance,
    // but a DB check can prevent issues if a user was deleted after token issuance.
    const user = await User.findById(decoded.user.id).select('-hashedPassword');
    if (!user) {
        return res.status(401).json({ message: 'Token is valid, but user not found.' });
    }
    req.user = user; // Or just req.user = decoded.user; if DB check is too much overhead per request
    
    next();
  } catch (err) {
    console.error('Auth middleware error:', err.message);
    res.status(401).json({ message: 'Token is not valid' });
  }
};
