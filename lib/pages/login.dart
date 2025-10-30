import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers store text input from the email and password fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Boolean used to manage loading state (true when waiting for login to complete)
  bool _loading = false;

  // Handles the main login process
  // 1. Validates email and password are not empty
  // 2. Calls AuthService().login(email, password)
  // 3. Shows success or error message
  // 4. Navigates to home on success
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 1. Ensure both fields are filled
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    // 2. Start loading indicator
    setState(() => _loading = true);

    try {
      // 3. Create instance of AuthService to handle API request
      final auth = AuthService();

      // 4. Send credentials to server for validation
      final res = await auth.login(email, password);

      // 5. If login success (ok == true)
      if (res['ok'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Logged in successfully')),
        );
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // 6. Handle failed login (wrong password or invalid credentials)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'].toString())),
        );
      }
    } catch (e) {
      // 7. Catch connection or unexpected errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    } finally {
      // 8. Always remove loading spinner at the end
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    // Dispose of controllers when page is closed to free memory
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Creates a reusable input decoration with consistent look for text fields
  // Includes light purple background, prefix icon, and rounded corners
  InputDecoration _createInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.purple.shade50,
      prefixIcon: Icon(icon, color: Colors.purple),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.purple.shade200),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar at the top with title and back button
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text('Login'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // Main body section of the login page
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title and welcome message
                const Text(
                  'Welcome Back',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter your credentials to login',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // Email input field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _createInputDecoration(hint: 'Email', icon: Icons.email),
                ),
                const SizedBox(height: 20),

                // Password input field (text hidden)
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _createInputDecoration(hint: 'Password', icon: Icons.lock),
                ),
                const SizedBox(height: 30),

                // Login button — disabled when loading
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _loading
                    // Show circular loading indicator when waiting for response
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    // Otherwise show normal text
                        : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 10),

                // Placeholder for "Forgot password" (can be implemented later)
                TextButton(
                  onPressed: () {
                    // Future implementation can go here
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.purple),
                  child: const Text('Forgot password?'),
                ),
                const SizedBox(height: 30),

                // Navigation link to signup page
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.purple),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
