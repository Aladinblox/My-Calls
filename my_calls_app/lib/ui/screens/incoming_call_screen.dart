import 'package:flutter/material.dart';
import 'package:my_calls_app/core/providers/call_provider.dart'; // Import CallProvider
import 'package:provider/provider.dart'; // Import Provider

class IncomingCallScreen extends StatelessWidget {
  final String callerId;
  final VoidCallback onAccept;
  final VoidCallback onReject;
// Note: callerId here is the ID. CallProvider should be enhanced to provide displayName for callerId.

  const IncomingCallScreen({
    super.key,
    required this.callerId, // This is an ID. Ideally, resolve to a display name.
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>(); // Watch for changes in callType
    final callType = callProvider.callType; 
    final String callTypeDisplay = callType == 'video' ? 'Video' : 'Voice';
    
    // TODO: Fetch/resolve callerId to a displayable name via CallProvider or another service.
    // For now, callerId (which is an ID from CallProvider) will be displayed.
    // CallProvider.callerId is the ID of the person calling.
    final String displayCallerName = callProvider.callerId ?? "Unknown Caller";


    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Spacer(flex: 2),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    callType == 'video' ? Icons.videocam_outlined : Icons.person_outline,
                    size: 70,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Incoming $callTypeDisplay Call',
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  displayCallerName, // Display the caller's ID (or resolved name)
                  style: TextStyle(
                    fontSize: 30, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20), // Space for ringing icon
                Icon( 
                  Icons.ring_volume_outlined, 
                  size: 50, 
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8)
                ),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround, // Distribute buttons evenly
                  children: <Widget>[
                    _buildCallActionButton(
                      context,
                      icon: Icons.call_end,
                      label: 'Reject',
                      backgroundColor: Colors.redAccent,
                      onPressed: onReject,
                    ),
                    _buildCallActionButton(
                      context,
                      icon: callType == 'video' ? Icons.videocam : Icons.call, // Icon changes with call type
                      label: 'Accept',
                      backgroundColor: Colors.green, // Standard accept color
                      onPressed: onAccept,
                    ),
                  ],
                ),
                const SizedBox(height: 20), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: label, 
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          elevation: 2.0, // Subtle shadow
          child: Icon(icon, color: Colors.white, size: 28), // Adjusted icon size
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
