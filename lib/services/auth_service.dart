import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';
import '../config/api_endpoints.dart';

// Purpose: Central place for all authentication actions: login, logout, and making requests that require a JWT.

class AuthService {
  // API endpoint URLs for authentication
  static const String _loginUrl = ApiEndpoints.login;
  static const String _logoutUrl = ApiEndpoints.logout;

  /// Authenticates user with email and password
  /// Returns a map with success status, message, token, and user data
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // Validate input parameters
      if (email.isEmpty || password.isEmpty) {
        return {
          'ok': false,
          'message': 'Please enter email and password',
        };
      }

      // Send login request to backend API
      final res = await http
          .post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(const Duration(seconds: 15));

      // Parse response data safely
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        
      }

      // Handle successful login (status 200)
      if (res.statusCode == 200) {
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          // Save JWT token securely for future requests
          await TokenStore.saveToken(token);
        }
        return {
          'ok': true,
          'message': data['message'] ?? 'Logged in successfully',
          'token': token,
          'user': data['user'] ?? {'email': email},
        };
      }

      // Handle failed login (non-200 status)
      return {
        'ok': false,
        'message': data['message'] ?? 'Login failed (status ${res.statusCode})',
      };
    } catch (e) {
      // Handle network or other errors
      return {
        'ok': false,
        'message': 'Error connecting to server: $e',
      };
    }
  }


  /// Logs out the current user and clears stored token
  /// Attempts to notify backend but always succeeds locally
  Future<Map<String, dynamic>> logout() async {
    try {
      // Get current token for API call
      final token = await TokenStore.getToken();

      if (token != null) {
        // Attempt to notify backend of logout
        final res = await http.post(
          Uri.parse(_logoutUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 5));

        // Parse successful logout response
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          return {
            'ok': true,
            'message': data['message'] ?? 'Logged out successfully',
          };
        }
      }

      // Return success even if API call fails
      return {
        'ok': true,
        'message': 'Logged out successfully',
      };
    } catch (e) {
      // Always return success for logout, even with errors
      return {
        'ok': true,
        'message': 'Logged out successfully',
      };
    } finally {
      // Always clear token from local storage
      await TokenStore.removeToken();
    }
  }

  /// Makes authenticated API requests with JWT token
  /// Handles token validation, expiration checks, and error responses
  static Future<Map<String, dynamic>> makeAuthenticatedRequest({
    required String url,
    required String method,
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    try {
      // Get stored authentication token
      final token = await TokenStore.getToken();

      if (token == null) {
        return {
          'ok': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      // Check if token is still valid before making request
      if (await TokenStore.hasValidToken() == false) {
        // Remove expired token and return error
        await TokenStore.removeToken();
        return {
          'ok': false,
          'message': 'Token expired. Please login again.',
        };
      }

      // Prepare request headers with authentication
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Add any custom headers if provided
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      // Execute HTTP request based on method type
      http.Response res;
      switch (method.toUpperCase()) {
        case 'GET':
          res = await http.get(Uri.parse(url), headers: headers);
          break;
        case 'POST':
          res = await http.post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          res = await http.put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          res = await http.delete(Uri.parse(url), headers: headers);
          break;
        default:
          return {
            'ok': false,
            'message': 'Unsupported HTTP method: $method',
          };
      }

      // Parse response data safely
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // Continue with empty data if JSON parsing fails
      }

      // Handle successful responses (2xx status codes)
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {
          'ok': true,
          'data': data,
          'message': data['message'] ?? 'Request successful',
        };
      } else {
        // Handle failed responses
        if (res.statusCode == 401) {
          // Remove invalid token on unauthorized response
          await TokenStore.removeToken();
        }

        return {
          'ok': false,
          'message': data['message'] ?? 'Request failed with status: ${res.statusCode}',
        };
      }
    } catch (e) {
      // Handle network or parsing errors
      return {
        'ok': false,
        'message': 'Network error: $e',
      };
    }
  }

  /// Checks if user is currently authenticated with a valid token
  /// Returns true if valid token exists, false otherwise
  static Future<bool> isAuthenticated() async {
    return await TokenStore.hasValidToken();
  }

  /// Gets current user's email from the stored JWT token
  /// Returns null if not authenticated or token is invalid
  static Future<String?> getCurrentUserEmail() async {
    return await TokenStore.getUserEmail();
  }
}

// The class uses:
// - http: sends requests to your backend.
// - TokenStore: saves/reads/removes the JWT and checks if it’s still valid.
// - ApiEndpoints: holds the URLs for login/logout (and others used elsewhere).

// Key fields: _loginUrl, _logoutUrl: pulled from ApiEndpoints to avoid hardcoding.

// Method: login(email, password)
// - Validates inputs are not empty.
// - POSTs credentials to the login endpoint.
// - On HTTP 200: reads the token, saves it via TokenStore.saveToken(), and returns { ok: true, message, token, user }.
// - On failure: returns { ok: false, message }.
// - Always catches network/JSON errors and responds with a clean object.

// Method: logout()
// - Reads the current token (if any).
// - Tries to notify the server by calling POST /logout with the token.
// - Regardless of the server response, always clears local token in finally.
// - Always returns { ok: true, message } so the UI can continue to log out.

// Method: makeAuthenticatedRequest({ url, method, body, additionalHeaders })
// - Reads the saved token. If missing: returns { ok: false, message }.
// - Checks if token is valid using TokenStore.hasValidToken().
//   If expired: removes token and returns { ok: false, message }.
// - Builds headers with Authorization: Bearer <token>.
// - Sends the request based on method (GET/POST/PUT/DELETE).
// - On 2xx: returns { ok: true, data, message }.
// - On 401: removes token (so the app can re-auth) and returns { ok: false, message }.
// - On other non-2xx: returns { ok: false, message }.
// - All parsing/network errors return a safe { ok: false, message }.

// Method: isAuthenticated()
// - Quick boolean: returns true if a valid token exists in TokenStore.

// Method: getCurrentUserEmail()
// - Reads the email claim from the stored JWT (if present), else null.

// Token lifecycle in this app flow:
// 1) User logs in → backend returns JWT → TokenStore.saveToken(token).
// 2) Any protected API call → makeAuthenticatedRequest attaches the token.
// 3) If token is invalid/expired or server replies 401 → token is removed.
// 4) UI should then route user to login.

// Return shape conventions (used by all public methods):
// - Success: { ok: true, ...optional fields... }
// - Failure: { ok: false, message }
// Keep your UI logic based on the ok flag and message.

// Timeouts currently used:
// - login: 15s
// - logout: 5s
// - makeAuthenticatedRequest: no explicit timeout here (can be added per need).

// Typical usage:
//   // Login
//   final res = await AuthService().login(email, password);
//   if (res['ok'] == true) {
//     // navigate to home
//   } else {
//     // show res['message']
//   }

//   // Logout
//   await AuthService().logout(); // then navigate to login

//   // Authenticated GET
//   final r = await AuthService.makeAuthenticatedRequest(
//     url: 'https://example.com/api/me',
//     method: 'GET',
//   );
//   if (r['ok'] == true) {
//     final data = r['data'];
//   } else {
//     // show r['message']; if token was cleared, redirect to login
//   }
