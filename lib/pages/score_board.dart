import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/api_endpoints.dart';
import '../services/auth_service.dart';
import '../services/sound_player.dart';

/// Shows the final score after finishing a quiz.
/// Pulls the user's name for a friendly message and supports sharing the result.
class ScoreBoardPage extends StatefulWidget {
  const ScoreBoardPage({super.key});

  @override
  State<ScoreBoardPage> createState() => _ScoreBoardPageState();
}

class _ScoreBoardPageState extends State<ScoreBoardPage> {
  // Stores the display name for the congratulation line
  String? _userName;

  // Controls the loading state while fetching user info
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserName();

    // Play celebration sound when score page opens
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await SoundPlayer.party();
      } catch (_) {
        // Ignore sound errors
      }
    });
  }

  // Fetches the current user's name from the authenticated endpoint
  Future<void> _fetchUserName() async {
    final res = await AuthService.makeAuthenticatedRequest(
      url: ApiEndpoints.me,
      method: 'GET',
    );

    String? name;
    if (res['ok'] == true) {
      final data = res['data'] as Map<String, dynamic>?;
      final user = (data?['user'] ?? data) as Map<String, dynamic>?;
      name = (user?['username'] ?? user?['name'] ?? user?['fullName']) as String?;
    }

    setState(() {
      _userName = name ?? 'User';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Read the score details passed from the quiz page
    // Expected shape: {'score': int, 'total': int, 'topic': String}
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final int score = (args?['score'] as int?) ?? 0;
    final int total = (args?['total'] as int?) ?? 20;
    final String topic = (args?['topic'] as String?) ?? 'Quiz';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // add function for Back to previous screen
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Score Board',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // While fetching username, show a spinner
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _Content(
                userName: _userName ?? 'User',
                score: score,
                total: total,
                topic: topic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateless part that shows the actual score UI and actions
class _Content extends StatelessWidget {
  const _Content({
    required this.userName,
    required this.score,
    required this.total,
    required this.topic,
  });

  final String userName;
  final int score;
  final int total;
  final String topic;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        // Basic horizontal padding for breathing room
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Big circle showing the score fraction
            _ScoreCircle(score: score, total: total),

            const SizedBox(height: 24),

            // headline
            Text(
              'Congratulations',
              style: TextStyle(
                color: Color(0xFF0F469A),
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            // customized message with username
            Text(
              'Great job, $userName! You did it in $topic',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0F469A),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 48),

            // Share button: uses share_plus to share plain text
            _PrimaryButton(
              label: 'Share',
              onPressed: () async {
                await Share.share('I scored $score/$total! Great job, $userName!');
              },
            ),

            const SizedBox(height: 16),

            // Back to home screen after viewing the score
            _PrimaryButton(
              label: 'Back to Home',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Circular score display widget
/// Shows a colored circle with Score and fraction
class _ScoreCircle extends StatelessWidget {
  const _ScoreCircle({required this.score, required this.total});
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0F469A).withOpacity(0.5),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 180,
        height: 180,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0F469A),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your Score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$score/$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Primary button used on this page
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Full width button
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F469A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
