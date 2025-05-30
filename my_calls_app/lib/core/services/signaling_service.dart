import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// Define a callback type for when a call is received
typedef OnIncomingCall = void Function(String callerId, String callType);
// Define a callback for when the call is accepted by the callee
typedef OnCallAccepted = void Function(RTCSessionDescription answer);
// Define a callback for when the call is rejected by the callee
typedef OnCallRejected = void Function(String reason);
// Define a callback for when an offer is received (for the callee)
typedef OnOfferReceived = void Function(RTCSessionDescription offer, String callerId);
// Define a callback for when an answer is received (for the caller)
typedef OnAnswerReceived = void Function(RTCSessionDescription answer);
// Define a callback for when an ICE candidate is received
typedef OnIceCandidateReceived = void Function(RTCIceCandidate candidate);
// Define a callback for when the other party ends the call
typedef OnCallEnded = void Function();
// Define a callback for when a new chat message is received
typedef OnNewMessage = void Function(Map<String, dynamic> messagePayload);
// Define a callback for when a presence update is received
typedef OnPresenceUpdate = void Function(Map<String, dynamic> presencePayload);


class SignalingService {
  WebSocketChannel? _channel;
  String? _selfId; // The current user's ID
  String? _token; // JWT token for authentication

  // Callbacks for various signaling events
  OnIncomingCall? onIncomingCall;
  OnCallAccepted? onCallAccepted; // Not directly used from server message, but for local state
  OnCallRejected? onCallRejected;
  OnOfferReceived? onOfferReceived;
  OnAnswerReceived? onAnswerReceived;
  OnIceCandidateReceived? onIceCandidateReceived;
  OnCallEnded? onCallEnded;
  OnNewMessage? onNewMessage; 
  OnPresenceUpdate? onPresenceUpdate; // Callback for presence updates
  VoidCallback? onConnectError;
  VoidCallback? onConnected;


  SignalingService();

  voidinit(String wsUrl, String token, String selfId) {
    _token = token;
    _selfId = selfId;
    _connect(wsUrl, token);
  }

  void _connect(String wsUrl, String token) {
    try {
      if (_channel != null && _channel!.closeCode == null) {
        debugPrint('SignalingService: Already connected or connecting.');
        return;
      }
      debugPrint('SignalingService: Connecting to $wsUrl?token=$token');
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );

      onConnected?.call();
      debugPrint('SignalingService: WebSocket connection established.');

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          debugPrint('SignalingService: WebSocket connection closed.');
          // Handle reconnection logic if needed
        },
        onError: (error) {
          debugPrint('SignalingService: WebSocket error: $error');
          onConnectError?.call();
          // Handle error and reconnection logic
        },
      );
    } catch (e) {
      debugPrint('SignalingService: Error connecting to WebSocket: $e');
      onConnectError?.call();
    }
  }

  void _handleMessage(String message) {
    debugPrint("SignalingService: Received message: $message");
    final Map<String, dynamic> decodedMessage = jsonDecode(message);
    final String type = decodedMessage['type'];
    final dynamic payload = decodedMessage['payload'];

    switch (type) {
      case 'incoming-call':
        final String callerId = payload['callerId'];
        final String callType = payload['callType'] ?? 'voice';
        onIncomingCall?.call(callerId, callType);
        break;
      case 'offer':
        final sdp = RTCSessionDescription(payload['sdp'], payload['type']);
        final String callerId = payload['senderId']; // The one who sent the offer
        onOfferReceived?.call(sdp, callerId);
        break;
      case 'answer':
        final sdp = RTCSessionDescription(payload['sdp'], payload['type']);
        onAnswerReceived?.call(sdp);
        break;
      case 'ice-candidate':
        final candidate = RTCIceCandidate(
          payload['candidate'],
          payload['sdpMid'],
          payload['sdpMLineIndex'],
        );
        onIceCandidateReceived?.call(candidate);
        break;
      case 'call-rejected':
        final String reason = payload['reason'] ?? 'Call rejected';
        onCallRejected?.call(reason);
        break;
      case 'call-accepted': // Server confirms callee accepted
         // This might be useful if the caller needs a server confirmation
         // For now, caller proceeds after sending offer and getting answer
        debugPrint("SignalingService: Call accepted by ${payload['senderId']}");
        // onCallAccepted is more of a local trigger after callee sends answer
        break;
      case 'call-ended':
        onCallEnded?.call();
        break;
      case 'call-error':
        debugPrint("SignalingService: Call error: ${payload['message']}");
        // Optionally, notify UI about call error (e.g., user unavailable)
        // onCallError?.call(payload['message']);
        break;
      case 'error':
        debugPrint("SignalingService: Server error: ${decodedMessage['message']}");
        break;
      case 'new-message': // Handle new chat messages from WebSocket
        if (payload is Map<String, dynamic>) {
          onNewMessage?.call(payload);
        } else {
          debugPrint("SignalingService: Received new-message with invalid payload type.");
        }
        break;
      case 'presence-update': // Handle presence updates from backend
        if (payload is Map<String, dynamic>) {
          onPresenceUpdate?.call(payload);
        } else {
          debugPrint("SignalingService: Received presence-update with invalid payload type.");
        }
        break;
      default:
        debugPrint('SignalingService: Unknown message type: $type');
    }
  }

  void _sendMessage(String type, Map<String, dynamic> payload) {
    if (_channel != null && _channel!.sink != null && _channel!.closeCode == null) {
      final message = jsonEncode({'type': type, 'payload': payload});
      debugPrint('SignalingService: Sending message: $message');
      _channel!.sink.add(message);
    } else {
      debugPrint('SignalingService: Cannot send message, channel is not active.');
    }
  }

  // Call initiation
  void callUser(String targetUserId, String callType) {
    _sendMessage('call-user', {'targetUserId': targetUserId, 'callType': callType});
  }

  // Send SDP Offer
  void sendOffer(String targetUserId, RTCSessionDescription sdp) {
    _sendMessage('offer', {
      'targetUserId': targetUserId,
      'sdp': sdp.sdp,
      'type': sdp.type,
    });
  }

  // Send SDP Answer
  void sendAnswer(String targetUserId, RTCSessionDescription sdp) {
    _sendMessage('answer', {
      'targetUserId': targetUserId, // This is the original caller
      'sdp': sdp.sdp,
      'type': sdp.type,
    });
  }

  // Send ICE Candidate
  void sendIceCandidate(String targetUserId, RTCIceCandidate candidate) {
    _sendMessage('ice-candidate', {
      'targetUserId': targetUserId,
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    });
  }

  // Notify server that call was accepted by callee (optional, server might not need this explicitly if answer is enough)
  void sendCallAccepted(String callerId) {
     _sendMessage('call-accepted', {'targetUserId': callerId});
  }

  // Notify server that call was rejected
  void sendCallRejected(String callerId, String reason) {
    _sendMessage('call-rejected', {'targetUserId': callerId, 'reason': reason});
  }

  // Notify server that call has ended
  void sendCallEnded(String targetUserId) {
    _sendMessage('call-ended', {'targetUserId': targetUserId});
  }

  // Send presence update
  void sendPresenceUpdate(String status) { // status: 'active' or 'idle'
    _sendMessage('update-presence', {'status': status});
  }

  void dispose() {
    debugPrint('SignalingService: Disposing and closing WebSocket channel.');
    _channel?.sink.close();
  }
}
