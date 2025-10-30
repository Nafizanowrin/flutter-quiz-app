import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';

// It checks if the user has a valid saved token and decides whether
// to navigate to the home screen or login screen.

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    // Start checking for valid token as soon as the splash screen loads
    _validateTokenAndNavigate();
  }

  // This method handles token checking and navigation.
  // If a valid token is found, it goes to home; otherwise, it goes to login.
  Future<void> _validateTokenAndNavigate() async {
    try {
      // Ask TokenStore if there’s a valid JWT token saved
      final hasValidToken = await TokenStore.hasValidToken();

      // Wait for 2 seconds so the splash screen shows briefly
      await Future.delayed(const Duration(seconds: 2));

      // Ensure that the widget is still in the UI tree before navigating
      if (!mounted) return;

      if (hasValidToken) {
        // If token is valid, navigate directly to the home page
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // If token is missing or expired, handle cleanup and go to login
        await _handleExpiredToken();
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // If anything unexpected happens, send the user to login for safety
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // This method runs if the token is expired or invalid.
  // It tries to log out through the AuthService (to clean server session)
  // and clears any locally saved token information.
  Future<void> _handleExpiredToken() async {
    try {
      // Try to get the stored token
      final token = await TokenStore.getToken();

      if (token != null) {
        // Token exists but might be invalid — attempt logout on the server
        final authService = AuthService();
        await authService.logout();
      } else {
        // No token saved — just clear local data if any remains
        await TokenStore.removeToken();
      }
    } catch (e) {
      // Even if logout fails, still clear local token to reset the app state
      await TokenStore.removeToken();
    }
  }

  // This builds the simple splash screen UI
  // It just shows the logo while the token check is running
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Plain white background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo inside a circle
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B35), // Orange color for the circle
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'T', // Logo text
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
