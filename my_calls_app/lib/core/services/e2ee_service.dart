import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;

// Removed MOCK_TOKEN import from call_provider, will get token via setAuthToken
// import 'package:my_calls_app/core/providers/call_provider.dart'; 


const String _API_URL_BASE_E2EE = "http://localhost:3000/api/keys"; // TODO: Centralize config

// Storage keys
const String _identityKeyStoreKey = '_e2ee_identityKey'; // Private identity key
const String _registrationIdStoreKey = '_e2ee_registrationId';
// PreKey, SignedPreKey private parts would also need secure storage
const String _preKeyPrivateStoreKeyPrefix = '_e2ee_preKey_private_';
const String _signedPreKeyPrivateStoreKeyPrefix = '_e2ee_signedPreKey_private_';
// Session data also needs secure storage
const String _sessionStoreKeyPrefix = '_e2ee_session_';


// Simple in-memory store for this example. Replace with persistent stores.
class InMemorySignalProtocolStore extends SignalProtocolStore {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SharedPreferences _prefs; // For non-sensitive or public parts if needed by library

  // These are simplified in-memory caches for the example.
  // A real implementation would fetch from secure storage / SharedPreferences as needed.
  IdentityKeyPair? _identityKeyPair;
  int? _localRegistrationId;
  final Map<int, PreKeyRecord> _preKeys = {};
  final Map<int, SignedPreKeyRecord> _signedPreKeys = {};
  final Map<SignalProtocolAddress, SessionRecord> _sessions = {};


  InMemorySignalProtocolStore(this._prefs);

  Future<void> _loadIdentity() async {
    if (_identityKeyPair == null) {
      String? privateKeyHex = await _secureStorage.read(key: _identityKeyStoreKey);
      if (privateKeyHex != null) {
        // This part is highly dependent on how IdentityKeyPair serializes.
        // Assuming it provides a way to reconstruct from private key bytes.
        // The library might require storing the public key too or handle it.
        // For now, this is a placeholder for actual deserialization.
        // _identityKeyPair = IdentityKeyPair.fromPrivateKeyBytes(Uint8List.fromList(hex.decode(privateKeyHex)));
        debugPrint("E2eeService: Identity key loaded (conceptual). Actual deserialization needed.");
      }
    }
    if (_localRegistrationId == null) {
      String? regIdStr = await _secureStorage.read(key: _registrationIdStoreKey);
      if (regIdStr != null) _localRegistrationId = int.tryParse(regIdStr);
    }
  }
  
  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    await _loadIdentity();
    if (_identityKeyPair == null) throw Exception("IdentityKeyPair not found/generated.");
    return _identityKeyPair!;
  }

  @override
  Future<int> getLocalRegistrationId() async {
    await _loadIdentity();
    if (_localRegistrationId == null) throw Exception("RegistrationId not found/generated.");
    return _localRegistrationId!;
  }

  @override
  Future<bool> saveIdentity(IdentityKeyPair identityKey, int registrationId) async {
    _identityKeyPair = identityKey;
    _localRegistrationId = registrationId;
    // Store private part of identityKey securely
    // Again, highly dependent on library's serialization. This is conceptual.
    // await _secureStorage.write(key: _identityKeyStoreKey, value: hex.encode(identityKey.getPrivateKey().serialize()));
    await _secureStorage.write(key: _identityKeyStoreKey, value: "dummy_private_identity_key_hex"); // Placeholder
    await _secureStorage.write(key: _registrationIdStoreKey, value: registrationId.toString());
    debugPrint("E2eeService: Identity and RegID saved (conceptually).");
    return true;
  }
  
  // PreKeyStore methods
  @override
  Future<bool> containsPreKey(int preKeyId) async => _preKeys.containsKey(preKeyId);
  @override
  Future<PreKeyRecord?> loadPreKey(int preKeyId) async => _preKeys[preKeyId];
  @override
  Future<void> removePreKey(int preKeyId) async => _preKeys.remove(preKeyId);
  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async => _preKeys[preKeyId] = record;

  // SignedPreKeyStore methods
  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async => _signedPreKeys.containsKey(signedPreKeyId);
  @override
  Future<SignedPreKeyRecord?> loadSignedPreKey(int signedPreKeyId) async => _signedPreKeys[signedPreKeyId];
  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async => _signedPreKeys.values.toList();
  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async => _signedPreKeys.remove(signedPreKeyId);
  @override
  Future<void> storeSignedPreKey(int signedPreKeyId, SignedPreKeyRecord record) async => _signedPreKeys[signedPreKeyId] = record;

  // SessionStore methods
  @override
  Future<bool> containsSession(SignalProtocolAddress address) async => _sessions.containsKey(address);
  @override
  Future<SessionRecord?> loadSession(SignalProtocolAddress address) async => _sessions[address];
  @override
  Future<List<int>> getSubDeviceSessions(String name) async => []; // Not dealing with multi-device for now
  @override
  Future<void> deleteSession(SignalProtocolAddress address) async => _sessions.remove(address);
  @override
  Future<void> deleteAllSessions(String name) async => _sessions.clear(); // Simplified
  @override
  Future<void> storeSession(SignalProtocolAddress address, SessionRecord record) async => _sessions[address] = record;

  // Helper to load all necessary data from secure storage for initialization
  Future<void> initFromStorage() async {
    await _loadIdentity();
    // TODO: Load PreKeys, SignedPreKeys, Sessions from secure storage
    // This is a complex part involving deserializing records.
    // For this example, we assume they are generated fresh or handled by the session builder.
    debugPrint("E2eeService: InMemorySignalProtocolStore initialized (conceptually from storage).");
  }
}


class E2eeService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final SignalProtocolStore _signalProtocolStore;
  IdentityKeyPair? _identityKeyPair; // Made nullable, initialized in initialize()
  int? _registrationId; // Made nullable
  String? _authToken; // To be set by AuthProvider

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  E2eeService(); // Constructor is now empty, rely on initialize and setAuthToken

  void setAuthToken(String? token) {
    _authToken = token;
    // Potentially re-initialize or check if keys need to be published if token becomes available
    // For now, initialize() is called separately by ChatProvider when auth is ready.
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_authToken == null) {
      debugPrint("E2eeService: Cannot initialize, auth token not set.");
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _signalProtocolStore = InMemorySignalProtocolStore(prefs);
    await (_signalProtocolStore as InMemorySignalProtocolStore).initFromStorage(); // Load existing identity/regId

    try {
      // Attempt to load existing identity
      _identityKeyPair = await _signalProtocolStore.getIdentityKeyPair();
      _registrationId = await _signalProtocolStore.getLocalRegistrationId();
      debugPrint("E2eeService: Loaded existing identity and registration ID.");
      // If keys exist, check if they need to be (re)published, e.g. if server indicates low prekeys
      // For simplicity, we don't auto-republish here unless it's first time.
    } catch (e) {
      debugPrint("E2eeService: No existing identity found or error loading, generating new keys. Error: $e");
      _identityKeyPair = generateIdentityKeyPair();
      _registrationId = generateRegistrationId(); 
      await _signalProtocolStore.saveIdentity(_identityKeyPair!, _registrationId!);
      
      final preKeys = generatePreKeys(0, 100);
      for (var pKey in preKeys) {
        await _signalProtocolStore.storePreKey(pKey.id, PreKeyRecord.fromPreKeyParameters(pKey));
      }
      
      final signedPreKeyId = Random().nextInt(0x7FFFFFFF); // Ensure this is a good range
      final signedPreKey = generateSignedPreKey(_identityKeyPair!, signedPreKeyId);
      await _signalProtocolStore.storeSignedPreKey(signedPreKey.id, SignedPreKeyRecord.fromSignedPreKeyParameters(signedPreKey));
      
      // Only publish if token is available (it should be if initialize is called correctly)
      if (_authToken != null) {
        await publishKeys();
      } else {
        debugPrint("E2eeService: Cannot publish keys, auth token not available during key generation.");
      }
    }
    _isInitialized = true;
    if (_identityKeyPair != null && _registrationId != null) {
        debugPrint("E2eeService Initialized. Identity: ${hex.encode(_identityKeyPair!.getPublicKey().serialize())}, RegID: $_registrationId");
    } else {
        debugPrint("E2eeService Initialized but identity/regId might be missing if generation failed before saving.");
    }
  }

  Future<void> publishKeys() async {
    // Ensure _identityKeyPair and _registrationId are not null
    if (_identityKeyPair == null || _registrationId == null) {
      debugPrint("E2eeService: Cannot publish keys, identity or registrationId is null.");
      // This might indicate a failure in the key generation/loading logic in initialize()
      // Or initialize() was not called or completed.
      // For robustness, could try to call initialize() again, or throw error.
      // For now, just return to prevent crash. Consider a more robust recovery or error signal.
      if (!_isInitialized) { // If not even initialized, try to initialize first.
          await initialize();
          // If still null after re-init, then there's a deeper issue.
          if (_identityKeyPair == null || _registrationId == null) return;
      } else {
          return; // If initialized but these are null, something went wrong.
      }
    }
    if (_authToken == null) {
        debugPrint("E2eeService: Cannot publish keys, auth token not set.");
        return;
    }

    final identityPublicKey = _identityKeyPair!.getPublicKey();
    final signedPreKeyRecord = (await _signalProtocolStore.loadSignedPreKeys()).first; // Assuming one for now
    final preKeyRecords = await Future.wait(
        List.generate(10, (index) => _signalProtocolStore.loadPreKey(index)) // Example: publish first 10
    );
    final publicOneTimePreKeys = preKeyRecords.where((p) => p!=null).map((p) => {'keyId': p!.id, 'publicKey': hex.encode(p.getKeyPair().publicKey.serialize())}).toList();


    final body = jsonEncode({
      'identityKey': hex.encode(identityPublicKey.serialize()),
      'registrationId': _registrationId!,
      'signedPreKey': {
        'keyId': signedPreKeyRecord.id,
        'publicKey': hex.encode(signedPreKeyRecord.getKeyPair().publicKey.serialize()),
        'signature': hex.encode(signedPreKeyRecord.signature),
      },
      'oneTimePreKeys': publicOneTimePreKeys,
    });

    try {
      debugPrint("E2eeService: Publishing keys to $_API_URL_BASE_E2EE/publish: $body");
      final response = await http.post(
        Uri.parse('$_API_URL_BASE_E2EE/publish'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _authToken!, // Assumes _authToken is set via setAuthToken
        },
        body: body,
      );
      if (response.statusCode == 200) {
        debugPrint('E2eeService: Keys published successfully.');
      } else {
        debugPrint('E2eeService: Failed to publish keys: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('E2eeService: Error publishing keys: $e');
    }
  }

  Future<bool> establishSession(String targetUserId) async {
    if (!_isInitialized || _authToken == null) {
        debugPrint("E2eeService: Not initialized or no auth token. Call initialize() and setAuthToken().");
        // Attempt to initialize if not already. This might be redundant if called from ChatProvider correctly.
        if (!_isInitialized) await initialize(); 
        if (_authToken == null) return false; // Still no token, cannot proceed.
    }
    debugPrint("E2eeService: Attempting to establish session with $targetUserId");

    try {
      final response = await http.get(
        Uri.parse('$_API_URL_BASE_E2EE/$targetUserId/bundle'),
        headers: {'x-auth-token': _authToken!},
      );

      if (response.statusCode == 200) {
        final bundleJson = jsonDecode(response.body);
        
        final remoteIdentityKey = DjbECPublicKey(Uint8List.fromList(hex.decode(bundleJson['identityKey'])));
        final remoteRegistrationId = bundleJson['registrationId'] as int;
        
        SignedPreKeyPublic? remoteSignedPreKey = null;
        if (bundleJson['signedPreKey'] != null) {
             remoteSignedPreKey = SignedPreKeyPublic(
                bundleJson['signedPreKey']['keyId'] as int,
                DjbECPublicKey(Uint8List.fromList(hex.decode(bundleJson['signedPreKey']['publicKey']))),
                Uint8List.fromList(hex.decode(bundleJson['signedPreKey']['signature']))
            );
        }

        PreKeyPublic? remoteOneTimePreKey = null;
        if (bundleJson['oneTimePreKey'] != null) {
            remoteOneTimePreKey = PreKeyPublic(
                bundleJson['oneTimePreKey']['keyId'] as int,
                DjbECPublicKey(Uint8List.fromList(hex.decode(bundleJson['oneTimePreKey']['publicKey'])))
            );
        }
        
        final preKeyBundle = PreKeyBundle(
          remoteRegistrationId,
          1, // deviceId, assume 1 for now
          remoteOneTimePreKey?.id, // preKeyId
          remoteOneTimePreKey?.publicKey, // preKeyPublic
          remoteSignedPreKey!.id, // signedPreKeyId
          remoteSignedPreKey.publicKey, // signedPreKeyPublic
          remoteSignedPreKey.signature, // signedPreKeySignature
          remoteIdentityKey // identityKey
        );

        final remoteAddress = SignalProtocolAddress(targetUserId, 1); // name (userId), deviceId
        final sessionBuilder = SessionBuilder(_signalProtocolStore, remoteAddress);
        await sessionBuilder.processPreKeyBundle(preKeyBundle);
        debugPrint("E2eeService: Session established with $targetUserId.");
        return true;
      } else {
        debugPrint('E2eeService: Failed to fetch key bundle for $targetUserId: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('E2eeService: Error establishing session with $targetUserId: $e');
      return false;
    }
  }
  
  Future<bool> hasSession(String targetUserId) async {
    if (!_isInitialized) await initialize();
    final remoteAddress = SignalProtocolAddress(targetUserId, 1);
    return _signalProtocolStore.containsSession(remoteAddress);
  }

  Future<Map<String, dynamic>?> encryptMessage(String targetUserId, String plaintext) async {
    if (!_isInitialized || _authToken == null) {
      debugPrint("E2eeService: Not initialized or no auth token for encryption.");
      if (!_isInitialized) await initialize();
      if (_authToken == null) return null;
    }
    final remoteAddress = SignalProtocolAddress(targetUserId, 1);

    if (!await hasSession(targetUserId)) {
      bool success = await establishSession(targetUserId);
      if (!success) {
        debugPrint("E2eeService: Failed to establish session before encrypting for $targetUserId.");
        return null;
      }
    }
    
    final sessionCipher = SessionCipher(_signalProtocolStore, remoteAddress);
    final ciphertextMessage = await sessionCipher.encrypt(Uint8List.fromList(utf8.encode(plaintext)));
    
    // The library should provide type (PreKeyWhisperMessage or WhisperMessage)
    // PreKeyWhisperMessage = 3, WhisperMessage = 1 (these are illustrative, check library)
    final type = ciphertextMessage.getType(); // This method might vary
    
    return {
      'ciphertext': base64Encode(ciphertextMessage.serialize()), // Or hex, but base64 is common for wire
      'type': type, // e.g., CiphertextMessage.PREKEY_TYPE or CiphertextMessage.WHISPER_TYPE
    };
  }

  Future<String?> decryptMessage(String senderUserId, String ciphertextBase64, int ciphertextType) async {
    if (!_isInitialized) {
        debugPrint("E2eeService: Not initialized for decryption.");
        // Decryption might be possible if session already exists, but init loads keys.
        // Consider if initialize() should be awaited here too, but it might re-publish keys.
        // For now, assume if not initialized, decryption will likely fail due to missing identity.
        await initialize(); // Try to initialize, but this might be too late if called from a BG handler without auth context.
        if (!_isInitialized) return "[Decryption failed: Service not ready]";
    }
    final remoteAddress = SignalProtocolAddress(senderUserId, 1);
    final sessionCipher = SessionCipher(_signalProtocolStore, remoteAddress);
    
    try {
      Uint8List plaintext;
      final ciphertextBytes = base64Decode(ciphertextBase64);

      if (ciphertextType == CiphertextMessage.PREKEY_TYPE) { // Check actual type from library
        final preKeyWhisperMessage = PreKeyWhisperMessage(serialized: ciphertextBytes);
        plaintext = await sessionCipher.decrypt(preKeyWhisperMessage);
      } else if (ciphertextType == CiphertextMessage.WHISPER_TYPE) {
        final whisperMessage = WhisperMessage(serialized: ciphertextBytes);
        plaintext = await sessionCipher.decrypt(whisperMessage);
      } else {
        debugPrint("E2eeService: Unknown ciphertext type: $ciphertextType");
        return null;
      }
      return utf8.decode(plaintext);
    } catch (e) {
      debugPrint("E2eeService: Error decrypting message from $senderUserId: $e");
      if (e is DuplicateMessageException) {
        debugPrint("E2eeService: Duplicate message detected.");
        return "[Duplicate message - already decrypted]";
      } else if (e is InvalidMessageException) {
        debugPrint("E2eeService: Invalid message format or MAC check failed.");
        return "[Message decryption failed: Invalid message]";
      } else if (e is InvalidKeyIdException) {
         debugPrint("E2eeService: Invalid PreKey ID, possibly out of sync. Attempt to re-establish session might be needed.");
        return "[Message decryption failed: Key error]";
      } else if (e is UntrustedIdentityException) {
        debugPrint("E2eeService: Untrusted identity. Handle identity change.");
        return "[Message decryption failed: Untrusted identity]";
      }
      return null; // Or rethrow specific errors
    }
  }
}
