# My Calls Backend (Node.js + Express.js + MongoDB)

This is the backend server for the My Calls application.

## Prerequisites

*   **Node.js and npm:** Ensure Node.js (which includes npm) is installed. You can download it from [https://nodejs.org/](https://nodejs.org/).
*   **MongoDB:** Ensure MongoDB is installed and running. You can find installation instructions at [https://docs.mongodb.com/manual/installation/](https://docs.mongodb.com/manual/installation/).

## Getting Started

1.  **Clone the repository** (or ensure you have this project directory).
2.  **Navigate to the project directory:** `cd my_calls_backend`
3.  **Install dependencies:** `npm install`
4.  **Set up environment variables:**
    *   Create a `.env` file in the root of the `my_calls_backend` directory.
    *   Add the following variables (adjust values as necessary):
        ```
        PORT=3000
        MONGODB_URI=mongodb://localhost:27017/my_calls_db
        JWT_SECRET=your_jwt_secret_key
        ```
5.  **Run the server (development mode):** `npm run dev`
    *   This will use `nodemon` to automatically restart the server on file changes.
6.  **Run the server (production mode):** `npm start`

The server should now be running on the port specified in your `.env` file (default is 3000).

## API Endpoints

### Authentication (`/api/auth`)
*   `POST /register`: Register a new user.
    *   Body: `{ "username": "optional_username", "displayName": "Your Name", "phoneNumber": "your_phone_number", "password": "your_password" }`
*   `POST /login`: Login an existing user.
    *   Body: `{ "phoneNumber": "your_phone_number", "password": "your_password" }`
    *   Returns: `{ "token": "jwt_token", "userId": "user_id", "displayName": "Your Name", ... }`

### Chat (`/api/chat`)
*Requires `x-auth-token` header for all endpoints.*
*   `POST /send`: Send a message.
    *   Body: `{ "receiverId": "target_user_id", "content": "your_message", "messageType": "text" (optional) }`
    *   Returns: The saved message object.
    *   Real-time: Pushes a `new-message` event via WebSocket to the receiver if connected.
*   `GET /conversations`: Get all conversations for the authenticated user.
    *   Returns: Array of conversation objects, sorted by last message timestamp.
*   `GET /messages/:userId`: Get messages for a conversation with the specified `userId`.
    *   Path parameter `:userId` is the ID of the other participant.
    *   Query parameters: `limit` (default 30), `offset` (default 0) for pagination.
    *   Returns: Array of message objects.

### Signaling (WebSocket)
*   Connect to `ws://your_server_address?token=YOUR_JWT_TOKEN`
*   Handles WebRTC signaling events: `call-user`, `offer`, `answer`, `ice-candidate`, `call-accepted`, `call-rejected`, `call-ended`.
*   Receives `new-message` events for real-time chat updates.

### E2EE Key Bundles (`/api/keys`)
*Requires `x-auth-token` header for all endpoints.*
*   `POST /publish`: Publish the authenticated user's E2EE public key bundle.
    *   Body: `{ "identityKey": "hex", "registrationId": number, "signedPreKey": { "keyId": number, "publicKey": "hex", "signature": "hex" }, "oneTimePreKeys": [{ "keyId": number, "publicKey": "hex" }] }`
*   `GET /:userId/bundle`: Get the public key bundle for a specified `userId`.
    *   Returns: `{ "identityKey", "registrationId", "signedPreKey", "oneTimePreKey" (one selected OTPK, or null if none available) }`
*   `GET /onetime/count`: Get the count of available one-time pre-keys for the authenticated user.
*   `POST /onetime/replenish`: Add a batch of new one-time pre-keys for the authenticated user.
    *   Body: `{ "oneTimePreKeys": [{ "keyId": number, "publicKey": "hex" }] }`

### User Profiles (`/api/users`)
*Requires `x-auth-token` header for all endpoints.*
*   `GET /:userId/profile`: Get a user's public profile information.
    *   Path parameter `:userId` is the ID of the user whose profile is being requested.
    *   Returns: `{ "_id", "username", "displayName", "phoneNumber", "createdAt" }` (or similar public fields).
*   `POST /presence`: (Optional) Get current presence for a list of user IDs.
    *   Body: `{ userIds: ["id1", "id2"] }`
    *   Returns: A map where keys are user IDs and values are `{ status, lastSeen }`.

### Presence (WebSocket)
*   **Client to Server:**
    *   `update-presence`: Sent by client when user activity changes.
        *   Payload: `{ status: 'active' | 'idle' }`
*   **Server to Client:**
    *   `presence-update`: Broadcast when a user's presence changes (connect, disconnect, status update).
        *   Payload: `{ userId, status, lastSeen }`
