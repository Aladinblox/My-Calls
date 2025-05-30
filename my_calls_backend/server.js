require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const http = require('http');
const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const User = require('./models/User');
const { initializeWebSocketManager } = require('./websocketManager');

const authRoutes = require('./routes/authRoutes');
const chatRoutes = require('./routes/chatRoutes');
const keyBundleRoutes = require('./routes/keyBundleRoutes');
const userRoutes = require('./routes/userRoutes'); // Import user routes

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Initialize WebSocketManager with the wss instance
initializeWebSocketManager(wss);

// Store user connections directly on wss object for access from chatController
// The websocketManager's getSocketServerInstance will return this wss.
wss.userConnections = new Map();

// Middleware
app.use(express.json()); // For parsing application/json

// Database Connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('MongoDB connected successfully.'))
  .catch(err => console.error('MongoDB connection error:', err));

// Basic Route
app.get('/', (req, res) => {
  res.send('My Calls Backend is running!');
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/keys', keyBundleRoutes);
app.use('/api/users', userRoutes); // Use user routes

// WebSocket Server Logic
wss.on('connection', (ws, req) => {
  // Example: ws://localhost:3000?token=YOUR_JWT_TOKEN
  const urlParams = new URLSearchParams(req.url.split('?')[1]);
  const token = urlParams.get('token');

  if (!token) {
    console.log('WebSocket connection attempt without token.');
    ws.terminate(); // Close connection if no token
    return;
  }

  let userId;
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    userId = decoded.user.id;
    wss.userConnections.set(userId, ws); 
    console.log(`User ${userId} connected via WebSocket. Total connections: ${wss.userConnections.size}`);
    ws.userId = userId;

    // Update presence to 'online' on connect
    updateAndBroadcastPresence(userId, 'online');

  } catch (err) {
    console.log('Invalid token for WebSocket connection.', err.message);
    ws.terminate();
    return;
  }

  ws.on('message', (message) => {
    try {
      const parsedMessage = JSON.parse(message);
      const { type, payload } = parsedMessage;
      const senderId = ws.userId; // userId of the sender

      console.log(`Received message type: ${type} from ${senderId}`);
      // console.log('Payload:', payload);

      const { targetUserId, sdp, candidate, callType, reason } = payload || {};

      // Route message to the target user if targetUserId is present
      const targetWs = targetUserId ? wss.userConnections.get(targetUserId) : null;

      switch (type) {
        case 'update-presence':
          if (payload && (payload.status === 'active' || payload.status === 'idle')) {
            // 'active' is treated as 'online' for simplicity in this model.
            // 'idle' is a distinct status.
            const newStatus = payload.status === 'active' ? 'online' : 'idle';
            updateAndBroadcastPresence(senderId, newStatus);
          } else {
            console.log("Invalid payload for update-presence:", payload);
          }
          break;
        // Keep existing call-related cases...
        case 'call-user': 
          if (targetWs && targetWs.readyState === WebSocket.OPEN) {
            console.log(`Forwarding 'call-user' from ${senderId} to ${targetUserId}`);
            targetWs.send(JSON.stringify({
              type: 'incoming-call',
              payload: { callerId: senderId, callType: callType || 'voice' } // callType can be 'voice' or 'video'
            }));
          } else {
            console.log(`User ${targetUserId} not connected or WebSocket not open.`);
            // Optionally, send a message back to caller: user unavailable
            ws.send(JSON.stringify({ type: 'call-error', payload: { message: `User ${targetUserId} is not available.`}}));
          }
          break;

        case 'offer': // Caller sends SDP offer to targetUserId
        case 'answer': // Callee sends SDP answer back to caller (targetUserId here is the original caller)
        case 'ice-candidate': // Both send ICE candidates to each other
          if (targetWs && targetWs.readyState === WebSocket.OPEN) {
            console.log(`Forwarding '${type}' from ${senderId} to ${targetUserId}`);
            targetWs.send(JSON.stringify({ type, payload: { ...payload, senderId } }));
          } else {
            console.log(`Cannot forward '${type}'. User ${targetUserId} not connected or WebSocket not open.`);
          }
          break;

        case 'call-accepted': // Callee accepts, notify original caller (targetUserId is the original caller)
        case 'call-rejected': // Callee rejects, notify original caller
        case 'call-ended':    // One party ends the call, notify the other party
          if (targetWs && targetWs.readyState === WebSocket.OPEN) {
            console.log(`Forwarding '${type}' from ${senderId} to ${targetUserId}`);
            targetWs.send(JSON.stringify({ type, payload: { ...payload, senderId } }));
          } else {
            console.log(`Cannot forward '${type}'. User ${targetUserId} not connected or WebSocket not open.`);
          }
          break;
        
        default:
          console.log(`Unknown message type: ${type}`);
          ws.send(JSON.stringify({ type: 'error', message: 'Unknown message type' }));
      }
    } catch (error) {
      console.error('Failed to parse message or handle client message:', error);
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid message format' }));
    }
  });

  ws.on('close', () => {
    if (ws.userId) {
      wss.userConnections.delete(ws.userId);
      console.log(`User ${ws.userId} disconnected. Total connections: ${wss.userConnections.size}`);
      // Update presence to 'offline' on disconnect
      updateAndBroadcastPresence(ws.userId, 'offline');
    } else {
      console.log('Unauthenticated WebSocket connection closed.');
    }
  });

  ws.on('error', (error) => {
    console.error(`WebSocket error for user ${ws.userId || 'unauthenticated'}:`, error);
    // Clean up on error might be redundant if 'close' always follows, but can be added if necessary.
    // if (ws.userId) wss.userConnections.delete(ws.userId);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server (HTTP and WebSocket) is running on port ${PORT}`);
});

// Helper function for presence
async function updateAndBroadcastPresence(userId, status) {
  let user;
  try {
    user = await User.findByIdAndUpdate(
      userId,
      { presenceStatus: status, lastSeen: new Date() },
      { new: true } // Return the updated document
    ).select('_id displayName username presenceStatus lastSeen'); // Select fields for broadcast

    if (!user) {
        console.log(`User ${userId} not found for presence update.`);
        return;
    }
  } catch (dbError) {
      console.error(`Database error updating presence for ${userId}:`, dbError);
      return;
  }
  
  console.log(`Presence updated for ${userId}: ${status}`);

  const presencePayload = {
    userId: user._id,
    // displayName: user.displayName, // Include if needed by clients directly from this message
    // username: user.username,
    status: user.presenceStatus,
    lastSeen: user.lastSeen.toISOString(),
  };

  // Broadcast to all connected clients (except sender, though for presence it's often fine)
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      // client.userId is set upon successful connection
      // No need to avoid sending to self if client can handle it (e.g. update its own status from this)
      // Or add: if (client.userId !== userId) { ... }
      client.send(JSON.stringify({
        type: 'presence-update',
        payload: presencePayload
      }));
    }
  });
}
