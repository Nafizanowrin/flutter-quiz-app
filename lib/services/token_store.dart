import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
// This class is responsible for securely saving, retrieving, and validating JWT tokens.
// It is used throughout the app to check login status and user identity.
class TokenStore {
  // Creates an instance of FlutterSecureStorage to store data securely on device.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // The key used to store the JWT token.
  static const String _tokenKey = 'jwt_auth_token';

  // Saves the JWT token securely on the device.
  // This keeps the user logged in even after closing the app.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }
  // Retrieves the JWT token from secure storage.
  // Returns null if no token has been saved.
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Deletes the saved JWT token.
  // Called when the user logs out or the token is invalid.
  static Future<void> removeToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Checks if a valid JWT token exists.
  // Returns true if token is present and not expired.
  // Also applies a 24-hour maximum lifetime limit for safety.
  static Future<bool> hasValidToken() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      // Use jwt_decoder to check expiration.
      if (JwtDecoder.isExpired(token)) return false;

      // Decode token to check issue time and apply 24-hour limit.
      final decoded = JwtDecoder.decode(token);
      final iatTimestamp = decoded['iat'] as int?;
      if (iatTimestamp == null) return true;

      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iatTimestamp * 1000);
      final cap = issuedAt.add(const Duration(hours: 24));
      return DateTime.now().isBefore(cap);
    } catch (e) {
      // If token cannot be decoded, treat it as invalid.
      return false;
    }
  }

  /// Decodes and returns the full token payload (data stored inside the JWT).
  /// This can include user ID, email, and issue/expiry times.
  static Future<Map<String, dynamic>?> getTokenData() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      return null;
    }
  }

  /// Returns the email stored in the token, if available.
  /// Returns null if the token is missing or invalid.
  static Future<String?> getUserEmail() async {
    final tokenData = await getTokenData();
    return tokenData?['email'] as String?;
  }

  /// Returns the user ID stored in the token, if available.
  /// Returns null if the token is missing or invalid.
  static Future<String?> getUserId() async {
    final tokenData = await getTokenData();
    return tokenData?['id'] as String?;
  }

  // Returns the expiry date of the token in a readable format.
  static Future<String?> getTokenExpiryDate() async {
    final tokenData = await getTokenData();
    if (tokenData == null) return null;

    try {
      // Get expiry timestamp (in seconds)
      final expTimestamp = tokenData['exp'] as int?;
      if (expTimestamp == null) return null;

      // Convert to DateTime
      DateTime expiryDate = DateTime.fromMillisecondsSinceEpoch(expTimestamp * 1000);

      // Apply a 24-hour limit if needed
      final iatTimestamp = tokenData['iat'] as int?;
      if (iatTimestamp != null) {
        final issuedAt = DateTime.fromMillisecondsSinceEpoch(iatTimestamp * 1000);
        final clientCap = issuedAt.add(const Duration(hours: 24));
        if (clientCap.isBefore(expiryDate)) {
          expiryDate = clientCap;
        }
      }

      // Format the expiry date for display
      return '${expiryDate.day}/${expiryDate.month}/${expiryDate.year} '
          '${expiryDate.hour}:${expiryDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }

  // Returns the issue date of the token in a readable format.
  static Future<String?> getTokenIssuedDate() async {
    final tokenData = await getTokenData();
    if (tokenData == null) return null;

    try {
      final iatTimestamp = tokenData['iat'] as int?;
      if (iatTimestamp == null) return null;

      final issuedDate = DateTime.fromMillisecondsSinceEpoch(iatTimestamp * 1000);
      return '${issuedDate.day}/${issuedDate.month}/${issuedDate.year} '
          '${issuedDate.hour}:${issuedDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }

  // Checks if the token is going to expire within minutes.
  // Helps to refresh or re-login before it becomes invalid.
  static Future<bool> isTokenExpiringSoon() async {
    final token = await getToken();
    if (token == null) return true;

    try {
      final tokenData = JwtDecoder.decode(token);
      final expTimestamp = tokenData['exp'] as int?;
      if (expTimestamp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(expTimestamp * 1000);
      final fiveMinutesFromNow = DateTime.now().add(const Duration(minutes: 5));

      return expiryDate.isBefore(fiveMinutesFromNow);
    } catch (e) {
      return true;
    }
  }
}

// purpose :
// - Safely manages JWT tokens for login sessions.
// - Stores them in secure storage so they remain private.
// - Checks if the token is expired or needs refreshing.

// Common functions:
// saveToken()      → Saves a token after login.
// getToken()       → Reads the saved token.
// removeToken()    → Deletes it during logout.
// hasValidToken()  → Checks if token is still valid.
// getTokenData()   → Returns the token details (decoded payload).
// getUserEmail()   → Returns the user’s email from the token.
// getUserId()      → Returns the user’s ID.
// getTokenExpiryDate() → Returns expiry date formatted.
// getTokenIssuedDate() → Returns issue date formatted.
// isTokenExpiringSoon() → Checks if token expires within 5 minutes.

// Used in:
// - Splash screen (to check login state).
// - Auth service (for API authentication).
// - Profile page (to show token info).

// Everything is static so you can call directly like:
//   await TokenStore.saveToken(token);
//   bool valid = await TokenStore.hasValidToken();
