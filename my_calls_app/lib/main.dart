import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:my_calls_app/core/providers/auth_provider.dart'; // Import AuthProvider
import 'package:my_calls_app/core/providers/call_provider.dart';
import 'package:my_calls_app/core/providers/chat_provider.dart';
import 'package:my_calls_app/core/providers/presence_provider.dart'; // Import PresenceProvider
import 'package:my_calls_app/core/services/e2ee_service.dart';
import 'package:my_calls_app/core/services/presence_service.dart'; // Import PresenceService
import 'package:my_calls_app/core/services/signaling_service.dart';
import 'package:my_calls_app/ui/screens/auth/login_screen.dart';
import 'package:my_calls_app/ui/screens/main_navigation_screen.dart';
import 'package:my_calls_app/ui/screens/splash_screen.dart'; // New: SplashScreen for auto-login check
import 'package:provider/provider.dart';
// Other imports remain the same
import 'package:flutter_webrtc/flutter_webrtc.dart'; // Required for WebRTC.platformIsDesktop etc.
// For kIsWeb:
import 'package:flutter/foundation.dart' show kIsWeb;


Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  if (WebRTC.platformIsDesktop || WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
    // Specific initializations if needed, like permissions for desktop
  } else if (kIsWeb) {
    // For web, you might need to prompt for permissions early or ensure HTTPS
    // await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Instantiate services that will be shared
    final signalingService = SignalingService(); 
    final e2eeService = E2eeService();
    // PresenceService will be instantiated via Provider and depends on AuthProvider

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider.value(value: signalingService), // Make SignalingService available directly if needed
        Provider.value(value: e2eeService),
        
        // PresenceService needs AuthProvider and SignalingService
        ProxyProvider2<AuthProvider, SignalingService, PresenceService>(
          update: (_, auth, signal, previous) => 
              previous ?? PresenceService(signal, auth),
          dispose: (_, service) => service.dispose(),
        ),

        ChangeNotifierProxyProvider<AuthProvider, CallProvider>(
          create: (context) => CallProvider(authProvider: Provider.of<AuthProvider>(context, listen: false)),
          update: (context, auth, previous) => previous!..updateAuthProvider(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (context) => ChatProvider(
            signalingService, // Provided directly or via context
            e2eeService,      // Provided directly or via context
            Provider.of<AuthProvider>(context, listen: false)
          ),
          update: (context, auth, previous) => previous!..updateAuthProvider(auth),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, SignalingService, PresenceProvider>(
           create: (context) => PresenceProvider(
                Provider.of<SignalingService>(context, listen: false),
                Provider.of<AuthProvider>(context, listen: false)
            ),
            update: (context, auth, signal, previous) => 
                previous!..updateAuthProvider(auth), // Assuming PresenceProvider has updateAuthProvider
        ),
      ],
      child: MaterialApp(
        title: 'My Calls App',
        theme: ThemeData( // Define the color palette here
          primarySwatch: Colors.blue, // Main primary color
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.blue,
            accentColor: Colors.amberAccent, // Accent color
            brightness: Brightness.light, // Default to light theme
          ),
          // Define other theme properties if needed (fontFamily, buttonTheme, etc.)
          // Example:
          // fontFamily: 'Roboto', // Ensure font is added to pubspec.yaml if not default
          // buttonTheme: ButtonThemeData(
          //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          //   textTheme: ButtonTextTheme.primary,
          // ),
          useMaterial3: true, // Enable Material 3 features if desired
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) { // For auto-login check
              return const SplashScreen(); // Shows a loading screen
            } else if (auth.isAuthenticated) {
              return const MainNavigationScreen();
            } else {
              return const LoginScreen(); // New LoginScreen to replace placeholder LoginPage
            }
          },
        ),
        // Define routes if you want named navigation for login/register later
        // routes: {
        //   '/login': (ctx) => const LoginScreen(),
        //   '/home': (ctx) => const MainNavigationScreen(),
        //   // ... other routes
        // },
      ),
    );
  }
}

// The old LoginPage placeholder can be removed or refactored into LoginScreen.
// For this task, I will assume LoginScreen is a new file.
}
