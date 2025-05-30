import 'package:flutter/material.dart';
import 'package:my_calls_app/ui/screens/call_screen_manager.dart';
import 'package:my_calls_app/ui/screens/chat/conversations_screen.dart'; // Will create this

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0; // 0 for Calls, 1 for Chat

  static const List<Widget> _widgetOptions = <Widget>[
    CallScreenManager(), // Handles call initiation (HomeScreen) and active call screens
    ConversationsScreen(), // Lists chats
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.call_outlined),
            activeIcon: Icon(Icons.call),
            label: 'Calls',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary, // Use theme color
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed, // Good for few items
        // backgroundColor: Theme.of(context).colorScheme.surfaceVariant, // Optional: for a different bg color
        onTap: _onItemTapped,
      ),
    );
  }
}
