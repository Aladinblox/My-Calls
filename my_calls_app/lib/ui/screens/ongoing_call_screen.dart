import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async'; // For Timer

class OngoingCallScreen extends StatefulWidget {
  final String targetUserId; // This should be display name
  final MediaStream? localStream;
  final MediaStream? remoteStream;
  final Duration callDuration;
  final bool isMuted;
  final bool isVideoEnabled; // New property
  final bool isFrontCamera;  // New property
  final VoidCallback onToggleMute;
  final Function(bool) onToggleVideo; // New property
  final VoidCallback onSwitchCamera; // New property
  final VoidCallback onEndCall;
  // final Function(bool) onToggleSpeaker; // Optional

  const OngoingCallScreen({
    super.key,
    required this.targetUserId,
    this.localStream,
    this.remoteStream,
    required this.callDuration,
    required this.isMuted,
    required this.isVideoEnabled,
    required this.isFrontCamera,
    required this.onToggleMute,
    required this.onToggleVideo,
    required this.onSwitchCamera,
    required this.onEndCall,
    // this.onToggleSpeaker,
  });

  @override
  State<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends State<OngoingCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  Timer? _timer;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.callDuration;
    _initializeRenderers();
    _startTimer();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localRenderer.srcObject = widget.localStream;
    _localRenderer.mirror = widget.isFrontCamera; // Mirror local video if front camera
    _remoteRenderer.srcObject = widget.remoteStream;
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: _duration.inSeconds + 1);
      });
    });
  }

  @override
  void didUpdateWidget(OngoingCallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.localStream != _localRenderer.srcObject) {
      _localRenderer.srcObject = widget.localStream;
    }
     if (widget.isFrontCamera != oldWidget.isFrontCamera) {
      _localRenderer.mirror = widget.isFrontCamera;
    }
    if (widget.remoteStream != _remoteRenderer.srcObject) {
      _remoteRenderer.srcObject = widget.remoteStream;
    }
    if (widget.callDuration != _duration && widget.callDuration.inSeconds > _duration.inSeconds) {
        _duration = widget.callDuration;
    }
     if (widget.isVideoEnabled != oldWidget.isVideoEnabled) {
      // If video is toggled off, renderer srcObject might become null or track disabled
      // If toggled on, srcObject should be updated by CallProvider logic
      _localRenderer.srcObject = widget.localStream; // ensure it's updated
    }
  }


  @override
  void dispose() {
    _timer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool showVideo = widget.isVideoEnabled && widget.localStream?.getVideoTracks().isNotEmpty == true;
    // Remote video depends on remote user sending video. For UI, assume if local video is on, we try to show remote.
    final bool showRemoteVideo = widget.isVideoEnabled && widget.remoteStream?.getVideoTracks().isNotEmpty == true;


    return Scaffold(
      backgroundColor: showVideo || showRemoteVideo ? Colors.black87 : theme.colorScheme.surfaceVariant,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Remote Video - takes the full screen if video is enabled
            if (showRemoteVideo)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            
            // Local Video - picture-in-picture style or full screen if remote is not available
            if (showVideo)
              Positioned(
                top: showRemoteVideo ? 20.0 : 0, // Full screen if no remote video
                right: showRemoteVideo ? 20.0 : 0,
                left: showRemoteVideo ? null : 0,
                bottom: showRemoteVideo ? null : 0,
                width: showRemoteVideo ? 110.0 : null, // Width for PiP
                height: showRemoteVideo ? 160.0 : null, // Height for PiP
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(showRemoteVideo ? 8.0 : 0),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: widget.isFrontCamera,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            // Call Info and Controls (Overlay)
            if (!showVideo && !showRemoteVideo) // Show avatar and name if no video
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     CircleAvatar(
                        radius: 60,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        child: Icon(Icons.person, size: 70, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.targetUserId, // Display name
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                    ),
                     const SizedBox(height: 10),
                  ],
                ),
              ),
            
            // Call duration display (always visible, maybe top center)
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _formatDuration(_duration),
                  style: TextStyle(
                    color: showVideo || showRemoteVideo ? Colors.white.withOpacity(0.8) : theme.colorScheme.onSurfaceVariant, 
                    fontSize: 18, 
                    fontWeight: FontWeight.w500,
                    shadows: showVideo || showRemoteVideo ? [const Shadow(blurRadius: 2, color: Colors.black38)] : null,
                  ),
                ),
              ),
            ),
            
            // Controls at the bottom
            Positioned(
              bottom: 40.0, // Increased bottom padding
            left: 20, // Added horizontal padding for the controls row
            right: 20,
            child: Column( // Main column for controls + potentially other info like target name if video is off
              mainAxisSize: MainAxisSize.min,
              children: [
                 if (showVideo || showRemoteVideo) // Show target name if videos are active (as it's not in center then)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 12.0),
                     child: Text(
                       'Call with ${widget.targetUserId}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9), 
                          fontSize: 18, 
                          fontWeight: FontWeight.w500,
                          shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
                        ),
                       textAlign: TextAlign.center,
                     ),
                   ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _buildControlButton(
                      icon: widget.isMuted ? Icons.mic_off : Icons.mic,
                      label: "Mute",
                      onPressed: widget.onToggleMute,
                      backgroundColor: widget.isMuted ? theme.colorScheme.primary : theme.colorScheme.secondaryContainer,
                      iconColor: widget.isMuted ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondaryContainer,
                    ),
                    _buildControlButton(
                      icon: widget.isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                      label: "Video",
                      onPressed: () => widget.onToggleVideo(!widget.isVideoEnabled),
                      backgroundColor: widget.isVideoEnabled ? theme.colorScheme.primary : theme.colorScheme.secondaryContainer,
                      iconColor: widget.isVideoEnabled ? theme.colorScheme.onPrimary : theme.colorScheme.onSecondaryContainer,
                    ),
                    if (widget.isVideoEnabled) // Only show switch camera if video is enabled
                       _buildControlButton(
                        icon: Icons.switch_camera,
                        label: "Switch",
                        onPressed: widget.onSwitchCamera,
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        iconColor: theme.colorScheme.onSecondaryContainer,
                      ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: "End",
                      onPressed: widget.onEndCall,
                      backgroundColor: Colors.redAccent,
                      iconColor: Colors.white,
                      isEndCall: true,
                    ),
                  ],
                ),
              ],
            )
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label, // Unique heroTag for each button
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          foregroundColor: iconColor,
          elevation: 2.0,
          mini: isEndCall ? false : true, // Smaller buttons for options, regular for end call
          child: Icon(icon, size: isEndCall ? 28 : 22),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9), 
            fontWeight: FontWeight.w500,
            fontSize: 12,
            shadows: const [Shadow(blurRadius: 1, color: Colors.black26)], // Text shadow for readability on video
          ),
        ),
      ],
    );
  }
}
