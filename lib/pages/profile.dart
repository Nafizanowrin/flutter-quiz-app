import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../config/api_endpoints.dart';

// ProfilePage shows user information fetched from the server.
// It verifies the token, loads user details, and displays profile data such as name, email, token info, and last login time.

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Holds the user details fetched from the API
  Map<String, dynamic>? _user;

  // Indicates loading state while fetching data
  bool _loading = true;

  // Stores any error message if something goes wrong
  String? _error;

  // Stores decoded token information for display
  String? _userEmail;
  String? _tokenExpiryDate;
  String? _tokenIssuedDate;

  @override
  void initState() {
    super.initState();
    // Load the profile when the page is first opened
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final hasToken = await TokenStore.hasValidToken();
      if (!hasToken) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
        }
        return;
      }

      // Load token details (for JWT info display)
      final email = await TokenStore.getUserEmail();
      final expiryDate = await TokenStore.getTokenExpiryDate();
      final issuedDate = await TokenStore.getTokenIssuedDate();

      // Make authenticated request to 'me' endpoint
      final res = await AuthService.makeAuthenticatedRequest(
        url: ApiEndpoints.me,
        method: 'GET',
      );

      // If the request succeeded
      if (res['ok'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final user = data?['user'] as Map<String, dynamic>? ?? data;

        // Save basic user info locally for other parts of app
        final prefs = await SharedPreferences.getInstance();
        final name = (user?['fullName'] ?? user?['firstName'] ?? '') as String?;
        final userEmail = (user?['email'] ?? '') as String?;
        if (name != null && name.isNotEmpty) {
          await prefs.setString('user_name', name);
        }
        if (userEmail != null && userEmail.isNotEmpty) {
          await prefs.setString('user_email', userEmail);
        }

        // Update the UI with the loaded data
        setState(() {
          _user = user;
          _userEmail = email;
          _tokenExpiryDate = expiryDate;
          _tokenIssuedDate = issuedDate;
          _loading = false;
        });
      } else {
        // If token expired or unauthorized, redirect to login
        final message = (res['message'] ?? 'Failed to load profile') as String;
        if (message.toLowerCase().contains('token') || message.contains('401')) {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }
          return;
        }
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    } catch (e) {
      // Catch any unexpected error like network, parsing, etc
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar with page title and back button
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text('Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // Main body shows loading spinner, error, or profile data
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _buildProfile(),
    );
  }

  // Builds the user profile display section
  Widget _buildProfile() {
    final name = (_user?['fullName'] ?? _user?['firstName'] ?? 'User').toString();
    final email = (_user?['email'] ?? '').toString();
    final imageUrl = (_user?['profileImg'] ??
        _user?['image'] ??
        _user?['avatar'] ??
        _user?['profileImage']) as String?;
    final role = (_user?['role'] ?? '').toString();
    final status = (_user?['status'] ?? '').toString();
    final lastLoggedInAt = (_user?['lastLoggedInAt'] ?? '').toString();
    final timezone = (_user?['timezone'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile card showing avatar, name, email, role, status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.purple.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // User profile picture
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.purple.withOpacity(0.08),
                    backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                        ? NetworkImage(imageUrl)
                        : null,
                    child: (imageUrl == null || imageUrl.isEmpty)
                        ? const Icon(Icons.person, color: Colors.purple, size: 40)
                        : null,
                  ),
                ),
                const SizedBox(height: 14),

                // User name
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),

                // User email (if available)
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 12),

                // Chips showing user status and role
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (status.isNotEmpty)
                      Chip(
                        label: Text(status),
                        backgroundColor: Colors.green.withOpacity(0.1),
                        labelStyle: const TextStyle(color: Colors.green),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (role.isNotEmpty)
                      Chip(
                        label: Text(role),
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        labelStyle: const TextStyle(color: Colors.purple),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Card showing JWT token information (email, issue date, expiry)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.purple.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'JWT Token Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(height: 15),

                if (_userEmail != null) ...[
                  _buildTokenInfoRow(
                    icon: Icons.email,
                    label: 'Email',
                    value: _userEmail!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_tokenIssuedDate != null) ...[
                  _buildTokenInfoRow(
                    icon: Icons.access_time,
                    label: 'Token Issued',
                    value: _tokenIssuedDate!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_tokenExpiryDate != null) ...[
                  _buildTokenInfoRow(
                    icon: Icons.schedule,
                    label: 'Token Expires',
                    value: _tokenExpiryDate!,
                    isExpiry: true,
                  ),
                ],
                if (_userEmail == null && _tokenExpiryDate == null) ...[
                  const Text(
                    'Token information not available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Optional card showing last login time and timezone
          if (lastLoggedInAt.isNotEmpty || timezone.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.purple.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  if (lastLoggedInAt.isNotEmpty)
                    _buildInfoRow(
                      icon: Icons.login,
                      label: 'Last login',
                      value: _formatIso(lastLoggedInAt),
                    ),
                  if (lastLoggedInAt.isNotEmpty && timezone.isNotEmpty)
                    const Divider(height: 20),
                  if (timezone.isNotEmpty)
                    _buildInfoRow(
                      icon: Icons.public,
                      label: 'Timezone',
                      value: timezone,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Reusable widget for displaying a small info row (used for last login and timezone)
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Reusable widget to display token-related information (email, issued, expiry)
  Widget _buildTokenInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isExpiry = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isExpiry ? Colors.orange : Colors.purple,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isExpiry ? Colors.orange[700] : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Converts ISO datetime string to readable local format (year-month-date Hr:min)
  String _formatIso(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final two = (int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return iso;
    }
  }
}
