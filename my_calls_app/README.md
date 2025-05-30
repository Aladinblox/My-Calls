# My Calls App (Flutter)

This is the mobile application for My Calls.

## Getting Started

1.  **Ensure Flutter is installed.** If not, follow the instructions at [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install).
2.  **Clone the repository** (or ensure you have this project directory).
3.  **Navigate to the project directory:** `cd my_calls_app`
4.  **Get dependencies:** `flutter pub get`
5.  **Configure Backend URL and User Details:**
    *   Open `lib/core/providers/call_provider.dart`.
    *   Update `MOCK_WEBSOCKET_URL` to point to your running backend (e.g., `ws://<your-ip>:3000` for physical device, `ws://10.0.2.2:3000` for Android emulator, `ws://localhost:3000` for iOS simulator if backend is local).
    *   For testing calls between two instances, you MUST:
        *   Change `MOCK_SELF_ID` to a unique ID for each app instance (e.g., "userA", "userB").
        *   Generate a valid JWT token for each `MOCK_SELF_ID` using the backend's `/api/auth/register` or `/api/auth/login` endpoints. Update `MOCK_TOKEN` in the code with this token. The WebSocket server uses this token for authentication.
6.  **Ensure Backend is Running:** Your `my_calls_backend` server must be running.
7.  **Permissions:**
    *   **Android:** Ensure the following permissions are in `android/app/src/main/AndroidManifest.xml` (usually within the `<manifest>` tag):
        ```xml
        <uses-permission android:name="android.permission.INTERNET"/>
        <uses-permission android:name="android.permission.RECORD_AUDIO"/>
        <uses-permission android:name="android.permission.CAMERA"/>
        <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
        <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
        <uses-permission android:name="android.permission.BLUETOOTH"/>
        <!-- For foreground service if you implement advanced call notifications -->
        <!-- <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/> -->
        ```
    *   **iOS:** Add the following keys to `ios/Runner/Info.plist` (usually within the main `<dict>` tag):
        ```xml
        <key>NSMicrophoneUsageDescription</key>
        <string>This app needs access to your microphone to make voice calls.</string>
        <key>NSCameraUsageDescription</key>
        <string>This app needs access to your camera for video calls (even if initially audio-only for WebRTC setup).</string>
        ```
    *   The app will request microphone permissions at runtime when a call is made or received.
8.  **Run the app:** `flutter run` (ensure an emulator is running or a device is connected).
    *   To test, run the app on two separate devices/emulators, each configured with a different `MOCK_SELF_ID` and corresponding `MOCK_TOKEN`.
    *   From one instance, enter the `MOCK_SELF_ID` of the other instance in the text field on the home screen and tap "Make Voice Call".
    *   For E2EE Chat: Keys are generated and published on first use of the chat feature (when `ChatProvider` is initialized). Ensure both users have done this once to be able to exchange encrypted messages.

## Implemented E2EE Details

*   **Protocol:** Signal Protocol (X3DH for session setup).
*   **Libraries Used:**
    *   `libsignal_protocol_dart` (or a similar Dart wrapper for Signal Protocol).
    *   `flutter_secure_storage` for storing sensitive private keys and session data.
    *   `shared_preferences` for non-sensitive metadata if needed by the Signal library's store.
*   **Key Management:**
    *   Identity keys, registration ID, signed pre-keys, and one-time pre-keys are generated on the client.
    *   Public parts of these keys are published to the backend (`/api/keys/publish`).
    *   Key bundles for other users are fetched from the backend (`/api/keys/:userId/bundle`) to establish sessions.
    *   The backend attempts to provide one unique one-time pre-key per bundle request.
*   **Message Flow:**
    *   Plaintext messages are encrypted using `E2eeService` before being sent via `ChatProvider`.
    *   The ciphertext and its type (prekey or regular) are sent to the backend.
    *   Incoming messages (via WebSocket or API fetch) are decrypted by `E2eeService` before display.
*   **Storage:**
    *   Private keys and session state are intended to be stored securely using `flutter_secure_storage` (though the current `InMemorySignalProtocolStore` in `E2eeService` is a placeholder and needs full secure persistence).
*   **Important Note:** The current `E2eeService` uses an `InMemorySignalProtocolStore` as a placeholder. For a production app, this store **MUST** be fully implemented using `flutter_secure_storage` to persist all sensitive cryptographic material securely and correctly handle serialization/deserialization of Signal Protocol objects.
