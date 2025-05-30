import 'package:flutter/material.dart';

class OutgoingCallScreen extends StatelessWidget {
  final String targetUserId; // This should ideally be displayName if available
  final VoidCallback onCancelCall;

  const OutgoingCallScreen({
    super.key,
    required this.targetUserId, // Pass displayName here if resolved by CallProvider/CallScreenManager
    required this.onCancelCall,
  });

  @override
  Widget build(BuildContext context) {
    // Note: targetUserId currently displays the ID. For actual displayName, CallProvider
    // would need to resolve it and CallScreenManager pass it here.

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant, // Consistent background
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    Icons.person_outline, 
                    size: 70, 
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Calling',
                  style: TextStyle(
                    fontSize: 20, 
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  targetUserId, // Display the name/ID passed
                  style: TextStyle(
                    fontSize: 30, 
                    fontWeight: FontWeight.w600, // Slightly bolder
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 25),
                Text(
                  'Ringing...',
                  style: TextStyle(
                    fontSize: 18, 
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                const Spacer(), // Pushes cancel button to the bottom
                ElevatedButton.icon(
                  onPressed: onCancelCall,
                  icon: const Icon(Icons.call_end, size: 24),
                  label: const Text('Cancel Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 20), // Spacing from bottom
              ],
            ),
          ),
        ),
      ),
    );
  }
}
