import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:my_calls_app/core/services/signaling_service.dart';
// import 'package:my_calls_app/models/user_model.dart'; // Assuming a user model for current user details

import 'package:my_calls_app/core/providers/auth_provider.dart'; // Import AuthProvider

// const String MOCK_SELF_ID = "user_self_temp_id"; // Replace with actual logged-in user ID
// const String MOCK_TOKEN = "mock_jwt_token_user_self"; // Replace with actual JWT token
const String WEBSOCKET_URL_BASE = "ws://localhost:3000"; // Ensure this matches your backend. TODO: Centralize config

enum CallState {
  idle,
  outgoing, // Call is being made to someone
  incoming, // A call is being received
  connected, // Call is active
}

class CallProvider with ChangeNotifier {
  final SignalingService _signalingService = SignalingService(); // Consider passing this in if shared
  AuthProvider? _authProvider; // To access token and user ID

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  CallState _callState = CallState.idle;
  String? _currentCallId; // Could be callerId or calleeId depending on context
  String? _targetUserId; // User being called
  String? _callerId; // User who is calling
  String? _callType; // 'voice' or 'video'

  bool _isMuted = false;
  bool _isSpeakerOn = true; // Default to speaker on for voice calls
  bool _isVideoEnabled = true; // Local video state
  bool _isFrontCameraActive = true;

  DateTime? _callStartTime;
  Duration _callDuration = Duration.zero;
  // Timer? _callDurationTimer; // To update duration periodically

  // Getters
  CallState get callState => _callState;
  String? get callType => _callType;
  String? get currentCallId => _currentCallId;
  String? get targetUserId => _targetUserId;
  String? get callerId => _callerId;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCameraActive => _isFrontCameraActive;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  Duration get callDuration => _callDuration;

  CallProvider({AuthProvider? authProvider}) : _authProvider = authProvider {
    _initializeSignaling();
    // Listen to AuthProvider changes if it's not passed in constructor or if it can change post-construction
    // This is handled by ChangeNotifierProxyProvider in main.dart via updateAuthProvider
  }

  void updateAuthProvider(AuthProvider authProvider) {
    bool needsReinitialization = (_authProvider?.token != authProvider.token || _authProvider?.currentUser?.id != authProvider.currentUser?.id);
    _authProvider = authProvider;
    if (needsReinitialization && _authProvider?.isAuthenticated == true) {
      _initializeSignaling();
    } else if (_authProvider?.isAuthenticated == false) {
      _signalingService.dispose(); // Close WebSocket if user logs out
    }
  }

  void _initializeSignaling() {
    if (_authProvider?.isAuthenticated == true) {
      final token = _authProvider!.token!;
      final selfId = _authProvider!.currentUser!.id;
      // Construct WebSocket URL, potentially with query params if needed by your SignalingService's _connect
      _signalingService.init(WEBSOCKET_URL_BASE, token, selfId); 
      _signalingService.onIncomingCall = _handleIncomingCall;
      _signalingService.onOfferReceived = _handleOfferReceived;
    } else {
      debugPrint("CallProvider: AuthProvider not authenticated, signaling not initialized.");
    }
   
    // These handlers can be set regardless of auth state, but actions might be blocked if not auth'd
    _signalingService.onAnswerReceived = _handleAnswerReceived;
    _signalingService.onIceCandidateReceived = _handleIceCandidateReceived;
    _signalingService.onCallRejected = _handleCallRejected;
    _signalingService.onCallEnded = _handleCallEnded;
    _signalingService.onConnectError = () {
        debugPrint("CallProvider: WebSocket connection error.");
        // Potentially update UI or state to reflect connection issue
    };
     _signalingService.onConnected = () {
        debugPrint("CallProvider: WebSocket connected successfully.");
    };
  }

  Future<void> _initializePeerConnection() async {
    if (_peerConnection != null) {
      await _peerConnection!.close();
    }

    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}, // Example STUN server
        // Add TURN servers here if needed for NAT traversal
      ]
    };
    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true, // Enable video
      },
      'optional': [],
    };

    _peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        final String? recipientId = (_callState == CallState.outgoing || _callState == CallState.connected && _targetUserId != null) ? _targetUserId : _callerId;
        if (recipientId != null) {
          _signalingService.sendIceCandidate(recipientId, candidate);
        }
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint("CallProvider: Remote track received. Tracks: ${event.track.kind}, Streams: ${event.streams.length}");
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
         debugPrint("CallProvider: Remote video track added to stream: ${event.streams[0].id}");
        _remoteStream = event.streams[0];
      } else if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
         debugPrint("CallProvider: Remote audio track added to stream: ${event.streams[0].id}");
        // If _remoteStream is already set by video, audio tracks are usually part of the same stream.
        // If not, this ensures audio-only calls still populate _remoteStream.
        if (_remoteStream == null) {
            _remoteStream = event.streams[0];
        } else {
            // Add audio track to existing remote stream if it's a different stream object for some reason
            // This part might need more robust handling depending on how tracks are streamed.
            // Usually, one stream from remote peer contains all tracks.
        }
      }
      notifyListeners();
    };
    
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint("CallProvider: Connection state changed: $state");
        // Handle states like 'failed', 'disconnected', 'closed'
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed || 
            state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
            if(_callState != CallState.idle) { // Avoid ending call if it was never started or already ended
                 _resetCallState("Connection failed or disconnected");
            }
        }
    };

    // Add local stream if available
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
    }
  }

  Future<void> _getUserMedia() async {
    if (_localStream != null && !_isVideoEnabled) { // If only disabling video, keep audio
        _localStream?.getVideoTracks().forEach((track) => track.stop());
        _localStream = null; // Force re-acquisition if video is re-enabled
    } else if (_localStream != null && _isVideoEnabled) { // Already have video stream
        return;
    }


    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': _isVideoEnabled ? {
        'facingMode': _isFrontCameraActive ? 'user' : 'environment',
        // Optional: specify resolution
        // 'width': {'ideal': 1280},
        // 'height': {'ideal': 720},
      } : false,
    };

    try {
      // Stop existing tracks before getting new stream, especially for camera switch
      _localStream?.getTracks().forEach((track) async {
        await track.stop();
      });
      _localStream?.dispose();


      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localStream = stream;

      if (!_isVideoEnabled) { // If video was disabled during prompt, ensure tracks are off
          _localStream?.getVideoTracks().forEach((track) {
              track.enabled = false;
              // track.stop(); // Consider stopping if not just toggling enabled state
          });
      } else {
         _localStream?.getVideoTracks().forEach((track) {
              track.enabled = true;
          });
      }


      // Add tracks to existing peer connection if it's already initialized
      if (_peerConnection != null) {
        // Remove old tracks before adding new ones, especially for camera switch
        List<RTCRtpSender> senders = await _peerConnection!.getSenders();
        for (var sender in senders) {
          if (sender.track?.kind == 'video' || sender.track?.kind == 'audio') {
            // await _peerConnection!.removeTrack(sender); // Careful with this, might renegotiate
          }
        }
        // Add new tracks
        _localStream!.getTracks().forEach((track) {
          _peerConnection!.addTrack(track, _localStream!);
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint("CallProvider: Error accessing media devices: $e");
      // Handle error (e.g., show message to user)
      // If video failed, try audio-only as fallback?
      if (_isVideoEnabled) {
        _isVideoEnabled = false; // Fallback to audio only if video fails
        notifyListeners();
        await _getUserMedia(); // Try again with audio only
      }
    }
  }

  // --- Call Actions ---
  Future<void> makeCall(String targetUserId, {String callType = 'video'}) async {
    if (_authProvider?.isAuthenticated != true) {
      debugPrint("CallProvider: User not authenticated. Cannot make call.");
      // Optionally, trigger UI update or show error
      return;
    }
    if (_callState != CallState.idle) {
      debugPrint("CallProvider: Cannot make call, already in a call or busy.");
      return;
    }
    _targetUserId = targetUserId;
    _callerId = _authProvider!.currentUser!.id; // Use actual self ID
    _callState = CallState.outgoing;
    _currentCallId = targetUserId; // For outgoing, current call is with target
    _callType = callType;
    _isVideoEnabled = (callType == 'video'); // Start with video enabled if it's a video call
    notifyListeners();

    await _getUserMedia(); // Get media with video based on _isVideoEnabled
    await _initializePeerConnection();

    if (_peerConnection == null) {
        debugPrint("CallProvider: PeerConnection not initialized.");
        _resetCallState("Failed to initialize connection");
        return;
    }
    
    // Send call initiation signal
    _signalingService.callUser(targetUserId, _callType!);

    // Create offer
    try {
        RTCSessionDescription offer = await _peerConnection!.createOffer();
        await _peerConnection!.setLocalDescription(offer);
        _signalingService.sendOffer(targetUserId, offer);
    } catch (e) {
        debugPrint("CallProvider: Error creating offer: $e");
        _resetCallState("Error creating offer");
    }
  }

  Future<void> acceptCall() async {
    if (_callState != CallState.incoming || _callerId == null) {
      debugPrint("CallProvider: No incoming call to accept or callerId is null.");
      return;
    }
    _callState = CallState.connected;
    _currentCallId = _callerId; // For incoming, current call is with caller
    _isVideoEnabled = (_callType == 'video'); // Callee enables video if it's a video call offer
    notifyListeners();

    await _getUserMedia(); // Ensure media is ready (with video if applicable)
    // Peer connection should have been initialized by _handleOfferReceived

    if (_peerConnection == null) {
        debugPrint("CallProvider: PeerConnection not initialized before accepting call.");
        _resetCallState("Connection error");
        return;
    }

    try {
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _signalingService.sendAnswer(_callerId!, answer); // Send answer to the caller
      _signalingService.sendCallAccepted(_callerId!); // Notify caller that call is accepted

      _callStartTime = DateTime.now();
      // _startCallDurationTimer(); // Implement if live duration is needed
      notifyListeners();
    } catch (e) {
      debugPrint("CallProvider: Error creating answer: $e");
      _resetCallState("Error creating answer");
    }
  }

  void rejectCall() {
    if (_callState != CallState.incoming || _callerId == null) {
      debugPrint("CallProvider: No incoming call to reject.");
      return;
    }
    _signalingService.sendCallRejected(_callerId!, 'Call rejected by user');
    _resetCallState('Call rejected');
  }

  void endCall() {
    if (_callState == CallState.idle) return;
    if (_authProvider?.isAuthenticated != true) {
      debugPrint("CallProvider: User not authenticated. Cannot end call (should not happen).");
      _resetCallState("Authentication error"); // Or handle differently
      return;
    }

    final String? selfId = _authProvider!.currentUser!.id;
    final String? recipientId = (_targetUserId == selfId || _targetUserId == null) ? _callerId : _targetUserId;
    
    if (recipientId != null) {
      _signalingService.sendCallEnded(recipientId);
    } else {
      // If no specific recipient (e.g. ending an outgoing call before connection or an incoming call before full setup)
      // we might need to notify based on current state.
      // If _callerId is set (incoming call), notify _callerId.
      // If _targetUserId is set (outgoing call), notify _targetUserId.
      // This part of the logic might need refinement based on specific call states and who to notify.
      if (_callerId != null && _callerId != selfId) _signalingService.sendCallEnded(_callerId!);
      else if (_targetUserId != null && _targetUserId != selfId) _signalingService.sendCallEnded(_targetUserId!);
    }
    _resetCallState('Call ended');
  }

  void _resetCallState(String reason) {
    debugPrint("CallProvider: Resetting call state. Reason: $reason");
    // _callDurationTimer?.cancel();
    // _callDurationTimer?.cancel();

    // Stop all local tracks and dispose of the stream
    _localStream?.getTracks().forEach((track) async {
      await track.stop();
    });
    await _localStream?.dispose();
    _localStream = null;

    // Stop all remote tracks and dispose of the stream
    _remoteStream?.getTracks().forEach((track) async {
      await track.stop();
    });
    await _remoteStream?.dispose();
    _remoteStream = null;

    await _peerConnection?.close();
    _peerConnection = null;

    _callState = CallState.idle;
    _currentCallId = null;
    _targetUserId = null;
    _callerId = null;
    _isMuted = false;
    _isVideoEnabled = true; // Reset video state
    _isFrontCameraActive = true; // Reset camera
    _callType = null;
    _callStartTime = null;
    _callDuration = Duration.zero;
    notifyListeners();
  }

  // --- Signaling Event Handlers ---
  void _handleIncomingCall(String callerId, String callType) {
    if (_callState == CallState.idle) {
      _callState = CallState.incoming;
      _callerId = callerId;
      _currentCallId = callerId;
      _callType = callType;
      _isVideoEnabled = (callType == 'video'); // Set based on incoming call type
      notifyListeners();
      // UI should now show incoming call screen, potentially with video indication
    } else {
      // Already in a call or busy, automatically reject
      _signalingService.sendCallRejected(callerId, 'User is busy');
    }
  }

  Future<void> _handleOfferReceived(RTCSessionDescription offer, String callerId) async {
    if (_callState != CallState.incoming || _callerId != callerId) {
      debugPrint("CallProvider: Received offer but not in incoming call state or callerId mismatch.");
      return;
    }
    
    await _initializePeerConnection(); // Initialize for the incoming call
    if (_peerConnection == null) {
        debugPrint("CallProvider: PeerConnection not initialized for offer.");
        _resetCallState("Failed to initialize for offer");
        return;
    }
    
    try {
        await _peerConnection!.setRemoteDescription(offer);
        // Now the user can choose to accept or reject.
        // If they accept, acceptCall() will create and send an answer.
    } catch (e) {
        debugPrint("CallProvider: Error setting remote description for offer: $e");
        _resetCallState("Error processing offer");
    }
  }

  Future<void> _handleAnswerReceived(RTCSessionDescription answer) async {
    if (_callState != CallState.outgoing && _callState != CallState.connected) {
        // Allow answer if we just connected (e.g. race condition where call-accepted from server arrives after answer)
      debugPrint("CallProvider: Received answer but not in outgoing call state.");
      return;
    }
    try {
        await _peerConnection?.setRemoteDescription(answer);
        _callState = CallState.connected; // Officially connected
        _callStartTime = DateTime.now();
        // _startCallDurationTimer();
        notifyListeners();
    } catch (e) {
        debugPrint("CallProvider: Error setting remote description for answer: $e");
        _resetCallState("Error processing answer");
    }
  }

  void _handleIceCandidateReceived(RTCIceCandidate candidate) {
    _peerConnection?.addCandidate(candidate).catchError((e) {
      debugPrint("CallProvider: Error adding received ICE candidate: $e");
    });
  }

  void _handleCallRejected(String reason) {
    if (_callState == CallState.outgoing) {
      _resetCallState('Call rejected by remote: $reason');
      // Show UI notification that call was rejected
    }
  }

  void _handleCallEnded() {
    _resetCallState('Call ended by remote');
    // Show UI notification that call has ended
  }

  // --- Media Controls ---
  void toggleMute() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final audioTrack = _localStream!.getAudioTracks()[0];
      audioTrack.enabled = !audioTrack.enabled;
      _isMuted = !audioTrack.enabled;
      notifyListeners();
    }
  }

  Future<void> toggleVideo(bool enable) async {
    if (_localStream != null) {
      _isVideoEnabled = enable;
      if (_localStream!.getVideoTracks().isNotEmpty) {
        _localStream!.getVideoTracks()[0].enabled = _isVideoEnabled;
      } else if (_isVideoEnabled) {
        // If no video track exists, and we want to enable it, we might need to re-acquire media.
        await _getUserMedia(); // This will re-evaluate constraints including video
      }
      notifyListeners();
    } else if (enable) { // If stream is null and we want to enable video
        _isVideoEnabled = true;
        await _getUserMedia(); // Acquire stream with video
    }
    // If part of an active call, may need to renegotiate or inform peer
    // For simplicity, WebRTC might handle this if tracks are added/removed/enabled/disabled.
    // If track is removed/added, renegotiation (new offer/answer) is typically needed.
    // If track 'enabled' status is toggled, renegotiation is often not needed.
  }

  Future<void> switchCamera() async {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final videoTrack = _localStream!.getVideoTracks()[0];
      // This is a simplified way to request camera switch.
      // Helper.switchCamera is more robust for flutter_webrtc.
      await Helper.switchCamera(videoTrack);
      _isFrontCameraActive = !_isFrontCameraActive; // Assume switch was successful
      notifyListeners();
    } else {
      // If no video track, just toggle the preferred camera for next _getUserMedia call
      _isFrontCameraActive = !_isFrontCameraActive;
      if (_isVideoEnabled && _localStream == null) { // If video is supposed to be on but stream is missing
          await _getUserMedia(); // Try to get stream with new camera
      }
      notifyListeners();
    }
  }


  void toggleSpeaker(bool enabled) {
    if (_remoteStream != null && _remoteStream!.getAudioTracks().isNotEmpty) {
        // For flutter_webrtc, speakerphone is usually managed by the system
        // or by using platform channels for more direct control.
        // This is a conceptual toggle.
        // On mobile, MediaStreamTrack.speakerPhone is not available.
        // You might need a package like `flutter_webrtc_speaker` or native code.
        debugPrint("CallProvider: Speaker toggle requested. Actual implementation may need platform channels.");
        _isSpeakerOn = enabled; // Update state, actual control needs platform specific code
        notifyListeners();
    }
     // For local audio output, if needed:
    // _localStream?.getAudioTracks().forEach((track) => track.enableSpeakerphone(enabled));
  }


  @override
  void dispose() {
    debugPrint("CallProvider: Disposing...");
    // _callDurationTimer?.cancel();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.dispose();
    _peerConnection?.dispose();
    _signalingService.dispose();
    super.dispose();
  }
}
