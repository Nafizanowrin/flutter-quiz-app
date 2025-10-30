// Home screen: Displays user info, categories, search, and recent quiz activity.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/token_store.dart';
import '../services/token_expiry_monitor.dart';
import '../services/quiz_score_store.dart';
import '../services/quiz_progress_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // User info
  String _name = 'User';
  String _email = '';
  String _profileImg = '';
  bool _isLoading = true;

  // Search/filter fields
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _activeTag = 'All';

  // Global countdown across quizzes
  Timer? _globalTick;
  int? _globalRemainSec;

  // Categories shown at top
  final List<Map<String, dynamic>> _allCategories = [
    {'title': 'HTML', 'tag': 'All', 'image': 'images/HTML.jpg'},
    {'title': 'JavaScript', 'tag': 'All', 'image': 'images/javascript.jpg'},
    {'title': 'React', 'tag': 'All', 'image': 'images/react.jpg'},
    {'title': 'C++', 'tag': 'All', 'image': 'images/c++.jpg'},
    {'title': 'Python', 'tag': 'All', 'image': 'images/python.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim()));
    TokenExpiryMonitor.startMonitoring(context);
    _startGlobalWatcher();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _globalTick?.cancel();
    TokenExpiryMonitor.stopMonitoring();
    super.dispose();
  }

  // Load user profile from API
  Future<void> _loadProfile() async {
    try {
      final token = await TokenStore.getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('https://api-staging.onesuite.io/api/auth/user'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = data['user'];
        setState(() {
          _name = (user['fullName'] ?? 'User').toString();
          _email = (user['email'] ?? '').toString();
          _profileImg = (user['profileImg'] ?? '').toString();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // Logout user and clear stored data
  Future<void> _logout(BuildContext context) async {
    try {
      TokenExpiryMonitor.stopMonitoring();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final authService = AuthService();
      await authService.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await QuizScoreStore.clearAllScores();
      await QuizProgressStore.clearGlobalDeadline();
      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      }
    }
  }

  // Navigate to specific quiz route
  void _navigateToQuiz(String categoryTitle) {
    String route;
    switch (categoryTitle.toUpperCase()) {
      case 'HTML':
        route = '/quiz-html';
        break;
      case 'JAVASCRIPT':
        route = '/quiz-javascript';
        break;
      case 'REACT':
        route = '/quiz-react';
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$categoryTitle quiz is coming soon!'), backgroundColor: Colors.orange),
        );
        return;
    }
    Navigator.pushNamed(context, route);
  }

  // Start and update global countdown
  Future<void> _startGlobalWatcher() async {
    await _updateGlobalRemaining();
    _globalTick?.cancel();
    _globalTick = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _updateGlobalRemaining();
    });
  }

  // Update remaining time or finalize expired quizzes
  Future<void> _updateGlobalRemaining() async {
    final deadline = await QuizProgressStore.getGlobalDeadlineMillis();
    if (deadline == null) {
      if (_globalRemainSec != null) setState(() => _globalRemainSec = null);
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final remain = ((deadline - now) / 1000).floor();
    if (remain <= 0) {
      await _autoFinalizeAllExpired();
      setState(() => _globalRemainSec = null);
    } else if (_globalRemainSec != remain) {
      setState(() => _globalRemainSec = remain);
    }
  }

  // Finalize all expired quizzes when time runs out
  Future<void> _autoFinalizeAllExpired() async {
    final topics = await QuizProgressStore.topicsWithProgress();
    if (topics.isEmpty) {
      await QuizProgressStore.clearGlobalDeadline();
      return;
    }
    const totals = {'HTML': 20, 'JavaScript': 20, 'React': 20};
    for (final t in topics) {
      final full = await QuizProgressStore.loadProgressFull(t);
      if (full == null) continue;
      final penalties = full.$5;
      final total = totals[t] ?? 20;
      final correct = await QuizProgressStore.getCorrectCount(t);
      final score = (correct - penalties).clamp(0, total);
      await QuizScoreStore.saveScore(t, score, total);
      await QuizProgressStore.markFinished(t, 0);
      await QuizProgressStore.clearProgress(t);
    }
    await QuizProgressStore.clearGlobalDeadline();
  }

  // Filter categories by search or tag
  List<Map<String, dynamic>> get _visibleCategories {
    final q = _query.toLowerCase();
    const showAllFor = {'All', 'Web', 'Mobile', 'Systems'};
    return _allCategories.where((c) {
      final tagOk = showAllFor.contains(_activeTag) ? true : (c['tag'] == _activeTag);
      final searchOk = q.isEmpty || (c['title'] as String).toLowerCase().contains(q);
      return tagOk && searchOk;
    }).toList();
  }

  // Format time as short readable text
  String _fmtHMSShort(int secs) {
    if (secs < 60) return '${secs}s';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m < 60) return '${m}m ${s.toString().padLeft(2, '0')}s';
    final h = m ~/ 60;
    final rm = m % 60;
    return '${h}h ${rm.toString().padLeft(2, '0')}m';
  }

  // Estimate remaining time for an ongoing quiz
  Future<String> _timeLabelFor(String topic, String fallback) async {
    try {
      final full = await QuizProgressStore.loadProgressFull(topic);
      if (full != null) {
        final idx = full.$1;
        final rem = full.$3;
        const perQuestion = 12;
        const totalQuestions = 20;
        final currentRem = (rem <= 0 || rem > perQuestion) ? perQuestion : rem;
        final remainingAfter = (totalQuestions - idx - 1).clamp(0, totalQuestions);
        final overall = currentRem + remainingAfter * perQuestion;
        return _fmtHMSShort(overall);
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  // Build complete page layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(elevation: 0, backgroundColor: const Color(0xFFF6F7FB), toolbarHeight: 0),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 14),
              _searchAndFilter(),
              const SizedBox(height: 18),
              Text('Categories', style: GoogleFonts.kufam(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 12),
              _categoriesRow(),
              const SizedBox(height: 18),
              Text('Recent Activity', style: GoogleFonts.kufam(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 12),
              _recentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  // Header with avatar, user info, and actions
  Widget _buildHeaderSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: _profileImg.isNotEmpty
                ? NetworkImage(_profileImg)
                : const AssetImage('images/signin.png') as ImageProvider,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name, style: GoogleFonts.kufam(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
                const SizedBox(height: 2),
                Text(_email.isEmpty ? '' : _email,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.kufam(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.diamond, color: Color(0xFF3F51B5), size: 18),
                const SizedBox(width: 6),
                Text('160', style: GoogleFonts.kufam(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF3F51B5))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.person, color: Colors.black54), onPressed: () => Navigator.pushNamed(context, '/profile')),
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () => _logout(context)),
        ],
      ),
    );
  }

  // Search bar with filter button
  Widget _searchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))
            ]),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: GoogleFonts.kufam(fontSize: 13, color: Colors.black45),
                prefixIcon: const Icon(Icons.search, color: Colors.black45),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 44,
          width: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))
            ]),
            child: IconButton(onPressed: _openFilterSheet, icon: const Icon(Icons.tune, color: Colors.black54)),
          ),
        )
      ],
    );
  }

  // Filter modal sheet for tags
  void _openFilterSheet() {
    final tags = const [
      {'label': 'All', 'icon': Icons.public},
      {'label': 'Web', 'icon': Icons.language},
      {'label': 'Mobile', 'icon': Icons.smartphone},
      {'label': 'Systems', 'icon': Icons.memory},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: tags.map((t) {
                final label = t['label'] as String;
                final icon = t['icon'] as IconData;
                final selected = _activeTag == label;
                return ChoiceChip(
                  labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  avatar: Icon(icon, size: 18, color: selected ? Colors.white : Colors.black54),
                  label: Text(label,
                      style: GoogleFonts.kufam(
                          fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.black87)),
                  selected: selected,
                  selectedColor: const Color(0xFF0F469A),
                  backgroundColor: const Color(0xFFF3F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  onSelected: (_) {
                    setState(() => _activeTag = label);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // Display horizontal category list
  Widget _categoriesRow() {
    return LayoutBuilder(
      builder: (ctx, c) {
        final isSmall = c.maxWidth < 360;
        final box = isSmall ? 52.0 : 58.0;
        final gap = isSmall ? 12.0 : 16.0;
        final items = _visibleCategories;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: items.map((cat) {
              return Padding(
                padding: EdgeInsets.only(right: gap),
                child: GestureDetector(
                  onTap: () => _navigateToQuiz(cat['title'] as String),
                  child: Column(
                    children: [
                      Container(
                        width: box,
                        height: box,
                        decoration: BoxDecoration(
                            color: const Color(0x45ABC2E3),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 6))
                            ]),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(cat['image'] as String, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: box + 8,
                        child: Text(cat['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.kufam(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.black)),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // Recent activity showing time and score
  Widget _recentActivitySection() {
    final items = [
      {'title': 'HTML', 'image': 'images/HTML.jpg', 'color': Colors.redAccent},
      {'title': 'JavaScript', 'image': 'images/javascript.jpg', 'color': Colors.amber},
      {'title': 'React', 'image': 'images/react.jpg', 'color': Colors.cyan},
      {'title': 'C++', 'image': 'images/c++.jpg', 'color': Colors.blue},
      {'title': 'Python', 'image': 'images/python.jpg', 'color': Colors.purple},
    ];
    const durations = {'HTML': '4 min', 'JavaScript': '4 min', 'React': '4 min', 'C++': '10 min', 'Python': '10 min'};

    return FutureBuilder<List<Widget>>(
      future: Future.wait(items.map((it) async {
        final title = it['title'] as String;
        final scoreText = await QuizScoreStore.getFormattedScore(title);
        final hasProgress = await QuizProgressStore.hasProgress(title);
        final normalized = scoreText.toLowerCase().replaceAll(RegExp(r'\s+'), '');
        final noFinishedScore = normalized.isEmpty || normalized == 'notrate' || normalized == 'noterate';

        if (noFinishedScore && !hasProgress) return const SizedBox.shrink();

        String? timeLabel;
        if (hasProgress) {
          timeLabel = (_globalRemainSec != null)
              ? _fmtHMSShort(_globalRemainSec!)
              : await _timeLabelFor(title, durations[title] ?? '30 min');
        } else {
          final taken = await QuizProgressStore.getTimeTakenSeconds(title);
          timeLabel = taken != null ? _fmtHMSShort(taken) : null;
        }

        final c = it['color'] as Color;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))
          ]),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: const Color(0xFFE8F0FF), borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset(it['image'] as String, fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: GoogleFonts.kufam(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                    Text('20 Questions', style: GoogleFonts.kufam(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 4),
                    if (timeLabel != null)
                      Row(children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.black45),
                        const SizedBox(width: 6),
                        Text(timeLabel, style: GoogleFonts.kufam(fontSize: 12, color: Colors.black54)),
                      ]),
                  ]),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 3.5)),
                  child: Center(
                    child: Text(
                      (!noFinishedScore ? scoreText : '...'),
                      style: GoogleFonts.kufam(fontSize: 10, fontWeight: FontWeight.bold, color: c),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              if (hasProgress)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () => _navigateToQuiz(title),
                      child: Text('Continue Quiz', style: GoogleFonts.kufam(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
            ]),
          ),
        );
      }).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final visible = snapshot.data!.where((w) => w is! SizedBox).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(children: visible);
      },
    );
  }
}


// -----------------------------------------------------------------------------
// Imported Libraries :
// dart:async -> Used for Timer and periodic countdown updates for the global quiz timer.
// dart:convert -> Used for decoding JSON responses from the API (user profile data).
// flutter/material.dart -> Provides all core UI widgets (Scaffold, AppBar, Buttons, Text, etc.).
// google_fonts.dart -> Provides custom Google Fonts for consistent typography.
// http.dart -> Used to make HTTP GET requests to fetch user profile info from the API.
// shared_preferences.dart -> Used for local storage of user data like name and email.
// auth_service.dart -> Handles login/logout and authentication API calls.
// token_store.dart -> Manages secure token storage and retrieval.
// token_expiry_monitor.dart -> Watches for token expiration and triggers logout if expired.
// quiz_score_store.dart -> Handles saving, retrieving, and clearing quiz scores locally.
// quiz_progress_store.dart -> Handles quiz progress, remaining time, and unfinished quiz data.


// Core Functionalities :
// 1. User Profile Management
//    - Loads the logged-in user's name, email, and profile image from the API.
//    - Displays profile info in the header section.
//    - Provides logout functionality that clears local data and navigates to login page.

// 2. Global Quiz Countdown
//    - A shared countdown timer used across all active quizzes.
//    - Continuously updates every second.
//    - Automatically finalizes and scores unfinished quizzes when time expires.
//    - Clears expired quiz progress from local storage after auto-finalization.

// 3. Search and Filter System
//    - Search field filters categories by keyword.
//    - Filter button opens a modal bottom sheet with category tags (All, Web, Mobile, Systems).
//    - The combination of search and filter determines visible categories in the UI.

// 4. Quiz Category Navigation
//    - Displays top categories (HTML, JavaScript, React, etc.) in a horizontal scrollable row.
//    - On tap, navigates the user to the selected quiz page (if route exists).
//    - Shows a "coming soon" message for unavailable quiz topics.

// 5. Recent Activity Display
//    - Lists each quiz topic with last known score or in-progress status.
//    - If a quiz is in progress, shows remaining time (from global countdown or per-topic estimate).
//    - Displays a "Continue Quiz" button for resuming unfinished quizzes.
//    - If the quiz is completed, shows total time taken and saved score.

// 6. Token and Session Handling
//    - TokenExpiryMonitor continuously checks if the user’s token is still valid.
//    - Automatically logs out if token expires to ensure security.
//    - Clears all quiz progress and score data when logging out.

// 7. UI Layout and Structure
//    - Scaffold and SafeArea provide main structure and padding for the screen.
//    - AppBar is minimal (hidden visually) for a clean layout.
//    - Scrollable body for dynamic content that fits smaller screens.
//    - Sections: Header → Search/Filter → Categories → Recent Activity.

// 8. Helper Methods
//    - _fmtHMSShort(): Formats seconds into readable time (e.g., “2m 30s” or “1h 05m”).
//    - _timeLabelFor(): Estimates remaining quiz time if global timer is inactive.
//    - _visibleCategories: Returns filtered categories based on search and tag filters.

// Overall :
// The HomePage serves as the dashboard for the quiz app.
// It gives users an overview of their account, quick access to quizzes,
// and insight into their recent performance and progress.

