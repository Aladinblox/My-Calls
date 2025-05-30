import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:my_calls_app/core/services/signaling_service.dart'; // To send updates
import 'package:my_calls_app/core/providers/auth_provider.dart'; // To check auth status

enum UserPresenceStatus { active, idle, offline }

class PresenceService with WidgetsBindingObserver {
  final SignalingService _signalingService;
  final AuthProvider _authProvider; // To ensure user is authenticated before sending updates

  Timer? _idleTimer;
  UserPresenceStatus _currentStatus = UserPresenceStatus.offline;
  bool _isAppResumed = false;

  // Configurable idle timeout (e.g., 2 minutes)
  final Duration _idleTimeout = const Duration(minutes: 2);

  PresenceService(this._signalingService, this._authProvider) {
    WidgetsBinding.instance.addObserver(this);
    _authProvider.addListener(_onAuthStateChanged);
    _initialize();
  }

  void _initialize() {
    if (_authProvider.isAuthenticated) {
      _isAppResumed = true; // Assume app starts in resumed state if authenticated
      _setStatus(UserPresenceStatus.active);
    }
  }

  void _onAuthStateChanged() {
    if (_authProvider.isAuthenticated) {
      _initialize();
    } else {
      // If user logs out, clear timer and set to offline (backend handles this on WS disconnect too)
      _idleTimer?.cancel();
      _currentStatus = UserPresenceStatus.offline;
      _isAppResumed = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_authProvider.isAuthenticated) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppResumed = true;
        // When app resumes, user is considered active immediately
        _setStatus(UserPresenceStatus.active);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive: // inactive might also be treated as idle/paused
      case AppLifecycleState.detached: // App is being destroyed
        _isAppResumed = false;
        // When app is paused or detached, user is idle (or offline if WS disconnects)
        _setStatus(UserPresenceStatus.idle); 
        break;
      case AppLifecycleState.hidden:
        // TODO: Handle hidden state if necessary for your platform/target.
        break;
    }
  }

  void _startIdleTimer() {
    _idleTimer?.cancel(); // Cancel any existing timer
    _idleTimer = Timer(_idleTimeout, () {
      if (_isAppResumed) { // Only set to idle if app is still resumed but timer expired
        _setStatus(UserPresenceStatus.idle);
      }
    });
  }

  // Call this on significant user interactions
  void onUserInteraction() {
    if (!_authProvider.isAuthenticated || !_isAppResumed) return;

    if (_currentStatus == UserPresenceStatus.idle && _isAppResumed) {
      // If coming from idle (and app is resumed), set to active
      _setStatus(UserPresenceStatus.active);
    } else if (_isAppResumed) {
      // If already active or some other state but app is resumed, just reset the timer
      _startIdleTimer();
    }
  }

  void _setStatus(UserPresenceStatus newStatus) {
    if (_currentStatus == newStatus && newStatus != UserPresenceStatus.active) {
      // Avoid redundant updates unless it's to re-affirm 'active' (which resets timer)
      // or if the status is genuinely changing.
      // If newStatus is 'active', we always proceed to reset the timer.
      if (newStatus == UserPresenceStatus.active && _currentStatus == UserPresenceStatus.active) {
         // Reset timer even if already active
      } else {
        return;
      }
    }
    
    _currentStatus = newStatus;
    debugPrint("PresenceService: Status changed to $_currentStatus");

    if (_currentStatus == UserPresenceStatus.active) {
      _startIdleTimer();
      _signalingService.sendPresenceUpdate('active');
    } else if (_currentStatus == UserPresenceStatus.idle) {
      _idleTimer?.cancel(); // Stop timer when idle
      _signalingService.sendPresenceUpdate('idle');
    }
    // 'offline' is primarily handled by WebSocket disconnect on backend.
    // Client might send 'idle' when going into background if it expects to be disconnected soon.
  }
  
  UserPresenceStatus get currentReportedStatus => _currentStatus;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider.removeListener(_onAuthStateChanged);
    _idleTimer?.cancel();
    debugPrint("PresenceService disposed.");
  }
}
