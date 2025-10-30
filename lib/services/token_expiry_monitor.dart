import 'dart:async';
import 'package:flutter/material.dart';
import 'token_store.dart';

class TokenExpiryMonitor {
  // Periodic timer that runs the check every second.
  static Timer? _timer;

  // We store a BuildContext so we can show dialogs and navigate.
  // This should be a context that stays alive while monitoring (e.g., a page).
  static BuildContext? _context;

  /// Starts the background check. Call this once (e.g., in a page's initState).
  /// Uses a 1-second tick so the UI reacts quickly when the token expires.
  static void startMonitoring(BuildContext context) {
    _context = context;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkExpiry();
    });
  }

  /// Stops the background check. Call this when the page is disposed
  /// or when you log out, to avoid running checks unnecessarily.
  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    _context = null;
  }
  /// Core check that runs on each tick:
  /// - If the context is gone, stop monitoring.
  /// - If the token is invalid or expired, show a popup and log out.
  static Future<void> _checkExpiry() async {
    if (_context == null || !_context!.mounted) {
      // No safe place to show UI; stop the timer.
      stopMonitoring();
      return;
    }

    // hasValidToken() returns false when missing/expired/invalid.
    final isExpired = !(await TokenStore.hasValidToken());

    if (isExpired) {
      _showExpiryPopup();
      // Avoid showing multiple popups by stopping the timer now.
      stopMonitoring();
    }
  }

  /// Small blocking dialog to inform the user.
  /// After a short delay, it will close itself and trigger logout navigation.
  static void _showExpiryPopup() {
    if (_context == null || !_context!.mounted) return;

    showDialog(
      context: _context!,
      barrierDismissible: false, // user cannot dismiss it manually
      builder: (context) {
        // After 2 seconds, close the dialog and proceed to logout.
        Timer(const Duration(seconds: 2), () {
          Navigator.pop(context); // close the dialog
          _logout(); // then navigate to login
        });

        return const AlertDialog(
          title: Text('Token Expired'),
          content: Text('Your session ended. You will be logged out now.'),
        );
      },
    );
  }

  /// Clears the token and navigates to the login screen.
  /// If anything goes wrong, we still force navigation to login as a fallback.
  static Future<void> _logout() async {
    try {
      // Remove any stored token to fully clear the session.
      await TokenStore.removeToken();

      // Send the user to the login screen, removing all previous routes.
      if (_context != null && _context!.mounted) {
        Navigator.pushNamedAndRemoveUntil(_context!, '/login', (_) => false);
      }
    } catch (_) {
      // Even if removal fails, still navigate to login to protect the session.
      if (_context != null && _context!.mounted) {
        Navigator.pushNamedAndRemoveUntil(_context!, '/login', (_) => false);
      }
    }
  }
}

//Call TokenExpiryMonitor.startMonitoring(context) when a page loads (e.g., Home).
//Call TokenExpiryMonitor.stopMonitoring() when that page is disposed or on manual logout.
//The monitor checks every second using TokenStore.hasValidToken().
// When expired, a short dialog appears, then the app redirects to /login.
