import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Controllers to manage text entered into each input field
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Boolean used to manage loading state when signup is processing
  bool _loading = false;

  Future<void> _handleSignup() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    // Make sure all fields have values
    if (username.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // Ensure both password fields match
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _loading = true);

    // This is currently just a placeholder until backend signup logic is added
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signup functionality not implemented yet')),
    );

    // Navigate back to login page after showing message
    Navigator.pop(context);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    // Dispose of all controllers to prevent memory leaks
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Uses background, icons, and rounded edges for a friendly form style
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
      // App bar with title and back button
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text('Sign Up'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // Body containing all form fields and buttons
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Main heading text
                const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Subtitle text under heading
                const Text('Create your account', textAlign: TextAlign.center),
                const SizedBox(height: 30),

                // Username input field
                TextField(
                  controller: _usernameController,
                  decoration: _createInputDecoration(hint: 'Username', icon: Icons.person),
                ),
                const SizedBox(height: 20),

                // Email input field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _createInputDecoration(hint: 'Email', icon: Icons.email),
                ),
                const SizedBox(height: 20),

                // Password input field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _createInputDecoration(hint: 'Password', icon: Icons.lock),
                ),
                const SizedBox(height: 20),

                // Confirm password input field
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: _createInputDecoration(hint: 'Confirm Password', icon: Icons.lock_outline),
                ),
                const SizedBox(height: 30),

                // Signup button (disabled when loading)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Sign Up'),
                  ),
                ),
                const SizedBox(height: 20),

                // Divider to visually separate normal signup from Google signup
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('Or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // Placeholder button for Google signup
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      // Future Google signup implementation will go here
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Sign in with Google'),
                  ),
                ),
                const SizedBox(height: 30),

                // Navigation link for users who already have an account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.purple),
                      child: const Text('Login'),
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
