import 'package:flutter/material.dart';
import 'package:my_calls_app/core/providers/auth_provider.dart'; // Import AuthProvider
import 'package:my_calls_app/core/providers/call_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // This screen is part of CallScreenManager, which is displayed under MainNavigationScreen's "Calls" tab.

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _targetUserIdController = TextEditingController();

  @override
  void dispose() {
    _targetUserIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Call'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Align content to top
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 20),
            Icon(Icons.contact_phone_outlined, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              'Enter User ID or Phone Number', // Placeholder for better user lookup later
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Text(
              'You can call any registered user if you know their ID.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _targetUserIdController,
              decoration: InputDecoration(
                labelText: 'User ID / Phone Number',
                hintText: 'e.g., user123 or +1234567890',
                prefixIcon: Icon(Icons.person_search_outlined, color: theme.colorScheme.primary.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              keyboardType: TextInputType.text, // General text for ID or phone
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              icon: const Icon(Icons.video_call_outlined),
              label: const Text('Make Video Call'),
              onPressed: () {
                final targetUserId = _targetUserIdController.text.trim();
                if (targetUserId.isNotEmpty) {
                  if (currentUser != null && targetUserId == currentUser.id) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("You cannot call yourself.")));
                    return;
                  }
                  // For now, targetUserId is passed directly.
                  // Ideally, resolve targetUserId to a display name before starting call UX.
                  callProvider.makeCall(targetUserId, callType: 'video');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a User ID or Phone Number.")));
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
             ElevatedButton.icon(
              icon: const Icon(Icons.call_outlined),
              label: const Text('Make Voice Call'),
              onPressed: () {
                final targetUserId = _targetUserIdController.text.trim();
                if (targetUserId.isNotEmpty) {
                   if (currentUser != null && targetUserId == currentUser.id) {
                     ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("You cannot call yourself.")));
                    return;
                  }
                  callProvider.makeCall(targetUserId, callType: 'voice');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a User ID or Phone Number.")));
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),
            if (currentUser != null)
              Text(
                "Your User ID: ${currentUser.id}\nYour Display Name: ${currentUser.bestDisplayName}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
