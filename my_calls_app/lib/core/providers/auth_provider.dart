import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:my_calls_app/core/models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Using the same MOCK_API_URL for now.
// TODO: Consolidate API URL configurations.
const String _MOCK_AUTH_API_URL = "http://localhost:3000/api/auth"; 

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();
    _token = await _secureStorage.read(key: 'auth_token');
    String? userJson = await _secureStorage.read(key: 'current_user');

    if (_token != null && userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
         debugPrint("AuthProvider: Auto login successful for ${_currentUser?.id}");
      } catch (e) {
        debugPrint("AuthProvider: Error decoding stored user: $e");
        await logout(); // Clear corrupted data
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register({
    String? username,
    required String displayName,
    required String phoneNumber,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$_MOCK_AUTH_API_URL/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username ?? displayName, // Fallback username to displayName if not provided
          'displayName': displayName,
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        _token = responseData['token'];
        _currentUser = UserModel.fromJson(responseData); // Backend returns user details

        await _secureStorage.write(key: 'auth_token', value: _token);
        await _secureStorage.write(key: 'current_user', value: jsonEncode(_currentUser!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        debugPrint('AuthProvider: Registration failed: ${response.statusCode} ${response.body}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('AuthProvider: Registration error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String phoneNumber, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$_MOCK_AUTH_API_URL/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phoneNumber': phoneNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _token = responseData['token'];
        _currentUser = UserModel.fromJson(responseData);

        await _secureStorage.write(key: 'auth_token', value: _token);
        await _secureStorage.write(key: 'current_user', value: jsonEncode(_currentUser!.toJson()));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        debugPrint('AuthProvider: Login failed: ${response.statusCode} ${response.body}');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('AuthProvider: Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'current_user');
    // Also, might need to clear other provider states, e.g., ChatProvider, CallProvider, E2eeService keys
    debugPrint("AuthProvider: User logged out.");
    notifyListeners();
  }
}
