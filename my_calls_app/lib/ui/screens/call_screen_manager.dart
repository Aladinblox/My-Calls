import 'package:flutter/material.dart';
import 'package:my_calls_app/core/providers/call_provider.dart';
import 'package:my_calls_app/ui/screens/home_screen.dart';
import 'package:my_calls_app/ui/screens/incoming_call_screen.dart';
import 'package:my_calls_app/ui/screens/ongoing_call_screen.dart';
import 'package:my_calls_app/ui/screens/outgoing_call_screen.dart';
import 'package:provider/provider.dart';

class CallScreenManager extends StatelessWidget {
  const CallScreenManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        switch (callProvider.callState) {
          case CallState.idle:
            return const HomeScreen(); // Screen to initiate calls
          case CallState.outgoing:
            return OutgoingCallScreen(
              targetUserId: callProvider.targetUserId ?? "Unknown User",
              onCancelCall: () => callProvider.endCall(), // Or a more specific cancelOutgoingCall
            );
          case CallState.incoming:
            return IncomingCallScreen(
              callerId: callProvider.callerId ?? "Unknown Caller",
              onAccept: () => callProvider.acceptCall(),
              onReject: () => callProvider.rejectCall(),
            );
          case CallState.connected:
            return OngoingCallScreen(
              // Pass necessary details like remote user ID, local/remote streams
              targetUserId: callProvider.currentCallId ?? "Connected User", // currentCallId should be set appropriately
              localStream: callProvider.localStream,
              remoteStream: callProvider.remoteStream,
              callDuration: callProvider.callDuration,
              isMuted: callProvider.isMuted,
              isVideoEnabled: callProvider.isVideoEnabled,
              isFrontCamera: callProvider.isFrontCameraActive,
              onToggleMute: () => callProvider.toggleMute(),
              onToggleVideo: (enable) => callProvider.toggleVideo(enable),
              onSwitchCamera: () => callProvider.switchCamera(),
              onEndCall: () => callProvider.endCall(),
              // onToggleSpeaker: (enabled) => callProvider.toggleSpeaker(enabled), // If implementing speaker toggle
            );
          default:
            return const HomeScreen(); // Fallback
        }
      },
    );
  }
}
