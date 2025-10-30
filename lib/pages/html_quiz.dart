import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quiz_score_store.dart';
import '../services/quiz_progress_store.dart';

// Purpose : This page manages the full HTML quiz flow for the user. It handles question display, timer countdown, progress saving, automatic advancement, and quiz completion.

class HtmlQuizPage extends StatefulWidget {
  const HtmlQuizPage({super.key});
  @override
  State<HtmlQuizPage> createState() => _HtmlQuizPageState();
}

class _HtmlQuizPageState extends State<HtmlQuizPage> with WidgetsBindingObserver {
  static const String _topic = 'HTML';

  // Track quiz state
  int currentIndex = 0;
  int? selectedIndex;
  bool showCorrectAnswer = false;

  // Stores all selected answers
  final List<int?> _answers = List<int?>.filled(_questions.length, null);

  // Timer and time tracking
  Timer? _tick;
  int _remaining = 12;
  int _penalties = 0;
  int _startMillis = 0;

  // Initializes listeners and starts timer when screen opens
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMillis = DateTime.now().millisecondsSinceEpoch;
    _loadSavedProgress().whenComplete(_startTimer);
  }

  // Clean up when leaving page
  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Automatically save progress if app goes background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  // Load saved progress if user previously left quiz midway
  Future<void> _loadSavedProgress() async {
    final full = await QuizProgressStore.loadProgressFull(_topic);
    if (full != null) {
      var idx = full.$1;
      List<int?> ans = List<int?>.from(full.$2);
      final rem = full.$3;
      final pen = full.$5;

      if (ans.length != _questions.length) {
        if (ans.length < _questions.length) {
          ans = [...ans, ...List<int?>.filled(_questions.length - ans.length, null)];
        } else {
          ans = ans.sublist(0, _questions.length);
        }
      }

      if (idx < 0) idx = 0;
      if (idx >= _questions.length) idx = _questions.length - 1;

      if (!mounted) return;
      setState(() {
        currentIndex = idx;
        for (int i = 0; i < _questions.length; i++) {
          _answers[i] = ans[i];
        }
        selectedIndex = _answers[currentIndex];
        showCorrectAnswer = _answers[currentIndex] != null && _answers[currentIndex] != -1;
        _remaining = (rem <= 0) ? 12 : rem;
        _penalties = pen;
      });
      return;
    }

    // For backward compatibility with old data format
    final legacy = await QuizProgressStore.loadProgress(_topic);
    if (legacy == null) return;
    var idx = legacy.$1;
    List<int?> ans = List<int?>.from(legacy.$2);

    if (ans.length != _questions.length) {
      if (ans.length < _questions.length) {
        ans = [...ans, ...List<int?>.filled(_questions.length - ans.length, null)];
      } else {
        ans = ans.sublist(0, _questions.length);
      }
    }
    if (idx < 0) idx = 0;
    if (idx >= _questions.length) idx = _questions.length - 1;

    if (!mounted) return;
    setState(() {
      currentIndex = idx;
      for (int i = 0; i < _questions.length; i++) {
        _answers[i] = ans[i];
      }
      selectedIndex = _answers[currentIndex];
      showCorrectAnswer = _answers[currentIndex] != null && _answers[currentIndex] != -1;
      _remaining = 12;
      _penalties = 0;
    });
  }

  // Save quiz progress locally (called periodically or when user exits)
  Future<void> _saveProgress() async {
    await QuizProgressStore.getOrStartGlobalDeadlineMillis(hours: 0.5);
    await QuizProgressStore.saveProgress(
      _topic,
      currentIndex,
      _answers,
      remainingSeconds: _remaining,
      lastSavedAtMillis: DateTime.now().millisecondsSinceEpoch,
      penalties: _penalties,
    );
  }

  // Starts per-question countdown timer
  void _startTimer() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      setState(() => _remaining--);

      // If question timer expires, auto-advance
      if (_remaining <= 0) _handleTimeoutAdvance();

      // If overall deadline reached, auto-finish quiz
      final globalDeadline = await QuizProgressStore.getGlobalDeadlineMillis();
      if (globalDeadline != null && DateTime.now().millisecondsSinceEpoch >= globalDeadline) {
        _finishQuiz(auto: true);
      }
    });
  }

  // Resets question timer when moving to next question
  void _resetTimer() {
    setState(() => _remaining = 12);
    _startTimer();
  }

  // If question timer ends without answer, apply penalty and go next
  void _handleTimeoutAdvance() {
    _tick?.cancel();
    if (_answers[currentIndex] == null) {
      _answers[currentIndex] = -1;
      _penalties++;
    }

    if (currentIndex < _questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedIndex = _answers[currentIndex];
        showCorrectAnswer =
            _answers[currentIndex] != null && _answers[currentIndex] != -1;
        _remaining = 12;
      });
      _startTimer();
      _saveProgress();
    } else {
      _finishQuiz();
    }
  }

  // Handles when user selects an answer
  void _recordSelection(int optionIndex) async {
    if (_answers[currentIndex] != null) return;
    setState(() {
      selectedIndex = optionIndex;
      _answers[currentIndex] = optionIndex;
      showCorrectAnswer = true;
    });

    // Increment correct counter if correct answer chosen
    if (optionIndex == _questions[currentIndex].answerIndex) {
      await QuizProgressStore.bumpCorrectCount(_topic);
    }

    _tick?.cancel();
    _saveProgress();
  }

  // Moves to next question or ends quiz if last one
  void _goNextOrFinish() {
    if (_answers[currentIndex] == null) {
      _answers[currentIndex] = -1;
    }
    if (currentIndex < _questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedIndex = _answers[currentIndex];
        showCorrectAnswer =
            _answers[currentIndex] != null && _answers[currentIndex] != -1;
      });
      _resetTimer();
      _saveProgress();
    } else {
      _finishQuiz();
    }
  }

  // Finalizes quiz, calculates score, and navigates to score screen
  Future<void> _finishQuiz({bool auto = false}) async {
    _tick?.cancel();
    final endMillis = DateTime.now().millisecondsSinceEpoch;
    final totalTakenSec = ((endMillis - _startMillis) / 1000).round();
    await QuizProgressStore.saveTimeTaken(_topic, totalTakenSec);

    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      final ans = _answers[i];
      if (ans != null && ans >= 0 && ans == _questions[i].answerIndex) {
        correct++;
      }
    }

    final score = (correct - _penalties).clamp(0, _questions.length);
    await QuizScoreStore.saveScore(_topic, score, _questions.length);
    await QuizProgressStore.clearProgress(_topic);

    if (!mounted) return;
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Time up! Quiz automatically finalized.'),
        backgroundColor: Colors.redAccent,
      ));
    }

    Navigator.pushNamed(
      context,
      '/score-board',
      arguments: {'score': score, 'total': _questions.length, 'topic': _topic},
    );
  }

  // Builds the UI of the quiz
  @override
  Widget build(BuildContext context) {
    final question = _questions[currentIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top navigation row with back and home buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      await _saveProgress();
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text('HTML',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () async {
                      await _saveProgress();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Main question container
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: title and remaining seconds
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Question',
                          style: TextStyle(
                              color: Color(0xFF0F469A),
                              fontWeight: FontWeight.w600)),
                      Text('$_remaining s',
                          style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),

                    // Question count and content
                    Text('Question: ${currentIndex + 1}/20',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(question.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // Options list
                    for (int i = 0; i < question.options.length; i++)
                      _OptionItem(
                        label: question.options[i],
                        selected: selectedIndex == i,
                        onTap: (_answers[currentIndex] != null)
                            ? null
                            : () => _recordSelection(i),
                        isCorrectAnswer: i == question.answerIndex,
                        showCorrectAnswer: showCorrectAnswer,
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            const Spacer(),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F469A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: null,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F469A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _goNextOrFinish,
                    child: Text(currentIndex == _questions.length - 1 ? 'Finish' : 'Next'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// Builds each answer option widget
class _OptionItem extends StatelessWidget {
  const _OptionItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isCorrectAnswer,
    required this.showCorrectAnswer,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool isCorrectAnswer;
  final bool showCorrectAnswer;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    if (showCorrectAnswer) {
      if (isCorrectAnswer) {
        bg = Colors.green;
        text = Colors.white;
      } else if (selected) {
        bg = Colors.red;
        text = Colors.white;
      } else {
        bg = Colors.white;
        text = Colors.black87;
      }
    } else {
      bg = selected ? const Color(0xFF0F469A) : Colors.white;
      text = selected ? Colors.white : Colors.black87;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: text, fontSize: 14, fontWeight: FontWeight.w500))),
            if (showCorrectAnswer && isCorrectAnswer)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ]),
        ),
      ),
    );
  }
}

// Represents a single question
class _Question {
  const _Question({required this.title, required this.options, required this.answerIndex});
  final String title;
  final List<String> options;
  final int answerIndex;
}

const List<_Question> _questions = [
  _Question(
    title: 'Who is making the Web standards?',
    options: [
      'The World Wide Web Consortium',
      'Microsoft',
      'Mozilla',
      'Google',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'What does HTML stand for?',
    options: [
      'Hyperlinks and Text Markup Language',
      'Home Tool Markup Language',
      'Hyper Text Markup Language',
      'Hyper Tool Multi Language',
    ],
    answerIndex: 2,
  ),
  _Question(
    title: 'Choose the correct HTML element for the largest heading:',
    options: ['<heading>', '<h6>', '<head>', '<h1>'],
    answerIndex: 3,
  ),
  _Question(
    title: 'What is the correct HTML element for inserting a line break?',
    options: ['<lb>', '<break>', '<br>', '<line>'],
    answerIndex: 2,
  ),
  _Question(
    title: 'What is the correct HTML for adding a background color?',
    options: [
      '<body bg="yellow">',
      '<background>yellow</background>',
      '<body style="background-color:yellow;">',
      '<bg>yellow</bg>',
    ],
    answerIndex: 2,
  ),
  _Question(
    title: 'Choose the correct HTML element to define important text',
    options: ['<b>', '<strong>', '<i>', '<important>'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which character is used to indicate an end tag?',
    options: ['*', '/', '<', '^'],
    answerIndex: 1,
  ),
  _Question(
    title: 'How can you open a link in a new tab/window?',
    options: [
      '<a href="url" target="_blank">',
      '<a href="url" new>',
      '<a href="url" target="new">',
      '<a href="url" open>',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'Which HTML element defines the title of a document?',
    options: ['<meta>', '<head>', '<title>', '<h1>'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Which HTML attribute specifies an alternate text for an image?',
    options: ['title', 'alt', 'src', 'longdesc'],
    answerIndex: 1,
  ),
  _Question(
    title: 'How can you make a numbered list?',
    options: ['<ul>', '<dl>', '<ol>', '<list>'],
    answerIndex: 2,
  ),
  _Question(
    title: 'How can you make a bulleted list?',
    options: ['<ul>', '<ol>', '<dl>', '<list>'],
    answerIndex: 0,
  ),
  _Question(
    title: 'What is the correct HTML for making a checkbox?',
    options: [
      '<checkbox>',
      '<input type="check">',
      '<input type="checkbox">',
      '<check>',
    ],
    answerIndex: 2,
  ),
  _Question(
    title: 'What is the correct HTML for inserting an image?',
    options: [
      '<img href="image.gif" alt="">',
      '<image src="image.gif" alt="">',
      '<img src="image.gif" alt="">',
      '<img alt="image.gif">',
    ],
    answerIndex: 2,
  ),
  _Question(
    title: 'Which doctype is correct for HTML5?',
    options: ['<!DOCTYPE html5>', '<!DOCTYPE HTML PUBLIC>', '<!DOCTYPE html>', '<!DOCTYPE HTML5>'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Which HTML element is used to specify a footer for a document or section?',
    options: ['<bottom>', '<footer>', '<section>', '<aside>'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which input type defines a slider control?',
    options: ['range', 'slider', 'scroll', 'number'],
    answerIndex: 0,
  ),
  _Question(
    title: 'What is the correct HTML element to play video files?',
    options: ['<media>', '<video>', '<movie>', '<player>'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which element is used to draw graphics on the fly?',
    options: ['<svg>', '<canvas>', '<graphic>', '<draw>'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which tag is used to define a navigation link section?',
    options: ['<navigation>', '<nav>', '<links>', '<menu>'],
    answerIndex: 1,
  ),
];


// 1. Major Responsibilities
//    - Displays one question at a time with four options.
//    - Tracks which question the user is currently on.
//    - Starts and resets a 12-second timer for each question.
//    - Automatically moves to the next question if time runs out.
//    - Allows user to select an answer and highlights correct/incorrect responses.
//    - Calculates score and penalties.
//    - Saves user progress locally so they can resume later.
//    - Finishes quiz when all questions are answered or the global deadline expires.

// 2. Local Data Management
//    - Uses QuizProgressStore to store quiz progress, time remaining, penalties,
//      and correct answer count in shared preferences.
//    - Uses QuizScoreStore to save the final quiz score for scoreboard display.

// 3. Time and Progress Handling
//    - Each question has a 12-second timer.
//    - A global deadline is also maintained (e.g., 30 minutes total for all quizzes).
//    - If the user leaves or pauses the app, progress is automatically saved.
//    - When quiz is finished, the total time taken is calculated and stored.

// 4. Navigation Flow
//    - Back button: Saves progress and goes back to the previous screen.
//    - Home button: Saves progress and returns to the home page.
//    - Next/Finish button: Moves to next question or finalizes the quiz.
//    - After completion, navigates to the ScoreBoard screen with score details.

// 5. UI Structure
//    - Top bar: Back and Home buttons with topic title ("HTML").
//    - Main container: Shows question number, timer, and question text.
//    - Option list: Tappable answers with color feedback for correct/incorrect selection.
//    - Bottom bar: “Previous” (disabled) and “Next/Finish” buttons.

// 6. External Libraries Used
//    - flutter/material.dart : For UI widgets and layout.
//    - dart:async : For Timer class to handle per-question countdown.
//    - quiz_progress_store.dart : Custom service for saving quiz progress and time.
//    - quiz_score_store.dart : Custom service for saving final quiz scores.

// 7. Key Methods
//    - _startTimer() : Starts or restarts the 1-second countdown timer.
//    - _resetTimer() : Resets question timer after each question.
//    - _recordSelection() : Records user’s selected answer.
//    - _handleTimeoutAdvance() : Moves automatically when timer hits zero.
//    - _goNextOrFinish() : Handles “Next” and “Finish” button actions.
//    - _finishQuiz() : Calculates total score, stores results, and redirects to scoreboard.
//    - _saveProgress() / _loadSavedProgress() : Handle saving and restoring progress.



