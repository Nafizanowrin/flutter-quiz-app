import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quiz_score_store.dart';
import '../services/quiz_progress_store.dart';
import '../services/sound_player.dart';
import 'package:flutter/services.dart';

class JavascriptQuizPage extends StatefulWidget {
  const JavascriptQuizPage({super.key});

  @override
  State<JavascriptQuizPage> createState() => _JavascriptQuizPageState();
}

class _JavascriptQuizPageState extends State<JavascriptQuizPage> with WidgetsBindingObserver {
  static const String _topic = 'JavaScript';

  // Quiz state for current question and selection
  int currentIndex = 0;
  int? selectedIndex;
  bool showCorrectAnswer = false;

  // One slot per question to hold chosen option index, or -1 for skipped
  final List<int?> _answers = List<int?>.filled(_questions.length, null);

  // Per-question countdown timer and penalty counter for timeouts
  Timer? _tick;
  int _remaining = 12;
  int _penalties = 0;

  // Used to compute total time taken for this quiz attempt
  int? _startMillis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start overall stopwatch and restore any saved progress,
    // then begin the per-question countdown.
    _startMillis = DateTime.now().millisecondsSinceEpoch;
    _loadSavedProgress().whenComplete(_startTimer);
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Save progress 
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  // Persist the current quiz state and ensure a global deadline exists
  Future<void> _saveProgress() async {
    // Starts a 30 minute global limit if one does not exist
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

  // Load saved progress if available: index, answers, remaining seconds, penalties
  Future<void> _loadSavedProgress() async {
    final full = await QuizProgressStore.loadProgressFull(_topic);
    if (full != null) {
      var idx = full.$1;
      List<int?> ans = List<int?>.from(full.$2);
      final rem = full.$3;
      final pen = full.$5;

      // Normalize saved answers array length if question set changed
      if (ans.length != _questions.length) {
        if (ans.length < _questions.length) {
          ans = [...ans, ...List<int?>.filled(_questions.length - ans.length, null)];
        } else {
          ans = ans.sublist(0, _questions.length);
        }
      }

      // current index into valid range
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

        // If saved remaining is invalid, fall back to full 12 seconds
        _remaining = (rem <= 0) ? 12 : rem;
        _penalties = pen;
      });
      return;
    }

    // Legacy path if only index and raw answers were saved
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

      // Defaults when legacy data missing enhanced fields
      _remaining = 12;
      _penalties = 0;
    });
  }

  // Start the per-question 1 second tick
  void _startTimer() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() => _remaining--);

      // If time for this question is up, advance
      if (_remaining <= 0) _onTimeoutAdvance();
    });
  }

  // Reset back to a fresh 12-second timer for the next question
  void _resetTimer() {
    setState(() => _remaining = 12);
    _startTimer();
  }

  // When a question times out, mark as skipped, add penalty, and move on
  void _onTimeoutAdvance() {
    _tick?.cancel();
    if (_answers[currentIndex] == null) {
      _answers[currentIndex] = -1;
      _penalties++;
    }

    if (currentIndex < _questions.length - 1) {
      setState(() {
        currentIndex++;
        selectedIndex = _answers[currentIndex];
        showCorrectAnswer = _answers[currentIndex] != null && _answers[currentIndex] != -1;
        _remaining = 12;
      });
      _startTimer();
      _saveProgress();
    } else {
      // finishing due to timeout on last question 
      _finishQuiz(auto: true);
    }
  }

  // Handles when user selects an answer (plays correct/wrong sound)
  void _recordSelection(int optionIndex) async {
    if (_answers[currentIndex] != null) return;

    // Determine if answer is correct
    final isCorrect = optionIndex == _questions[currentIndex].answerIndex;

    try {
      // Play sound depending on correctness
      if (isCorrect) {
        await SoundPlayer.correct();
      } else {
        await SoundPlayer.wrong();
      }

      // Add haptic feedback right after sound
      HapticFeedback.lightImpact();
    } catch (_) {}

    // Update UI and store progress
    setState(() {
      selectedIndex = optionIndex;
      _answers[currentIndex] = optionIndex;
      showCorrectAnswer = true;
    });

    if (isCorrect) {
      await QuizProgressStore.bumpCorrectCount(_topic);
    }

    _tick?.cancel();
    await _saveProgress();
  }

  // Button handler to proceed or finish the quiz
  Future<void> _goNextOrFinish() async {
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

  // Finalize: compute score, store results, clear progress, and navigate
  Future<void> _finishQuiz({bool auto = false}) async {
    _tick?.cancel();

    // Save total time taken for this attempt
    final endMillis = DateTime.now().millisecondsSinceEpoch;
    final totalTakenSec = ((endMillis - (_startMillis ?? endMillis)) / 1000).round();

    // Count correct answers
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      final ans = _answers[i];
      if (ans != null && ans >= 0 && ans == _questions[i].answerIndex) {
        correct++;
      }
    }

    // Score reduces by penalties for timeouts or skips
    final score = (correct - _penalties).clamp(0, _questions.length);

    await QuizScoreStore.saveScore(_topic, score, _questions.length);
    await QuizProgressStore.saveTimeTaken(_topic, totalTakenSec);

    // add record attempt for history (normal or timed-out)
    await QuizScoreStore.saveAttempt(
      _topic,
      score,
      _questions.length,
      finishedAtMillis: endMillis,
      takenSeconds: totalTakenSec,
      timedOut: auto,
    );

    // Mark finished, then clear progress
    await QuizProgressStore.markFinished(_topic, 0);
    await QuizProgressStore.clearProgress(_topic);

    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/score-board',
      arguments: {'score': score, 'total': _questions.length, 'topic': _topic},
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with back, title, home
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
                    child: Text(
                      'JavaScript',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
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

            // Question card with timer, index, prompt, and options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Question', style: TextStyle(color: Color(0xFF0F469A), fontWeight: FontWeight.w600)),
                      Text('${_remaining}s', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Question: ${currentIndex + 1}/20', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(question.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // Choices
                    for (int i = 0; i < question.options.length; i++)
                      _OptionItem(
                        label: question.options[i],
                        selected: selectedIndex == i,
                        onTap: (_answers[currentIndex] != null) ? null : () => _recordSelection(i),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: null, // disabled previous option
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

// A single answer option row with dynamic colors for selection and correctness
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
    Color backgroundColor;
    Color textColor;

    // After answering, mark correct green and wrong red
    if (showCorrectAnswer) {
      if (isCorrectAnswer) {
        backgroundColor = Colors.green;
        textColor = Colors.white;
      } else if (selected) {
        backgroundColor = Colors.red;
        textColor = Colors.white;
      } else {
        backgroundColor = Colors.white;
        textColor = Colors.black87;
      }
    } else {
      // Before answering, use highlight for the current selection
      backgroundColor = selected ? const Color(0xFF0F469A) : Colors.white;
      textColor = selected ? Colors.white : Colors.black87;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.black12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
              if (showCorrectAnswer && isCorrectAnswer)
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Simple model for a quiz question
class _Question {
  const _Question({
    required this.title,
    required this.options,
    required this.answerIndex,
  });

  final String title;
  final List<String> options;
  final int answerIndex;
}

const List<_Question> _questions = [
  _Question(
    title: 'Which company originally developed JavaScript?',
    options: ['Microsoft', 'Netscape', 'Sun Microsystems', 'Oracle'],
    answerIndex: 1,
  ),
  _Question(
    title: 'How do you write a single-line comment?',
    options: ['<!-- comment -->', '# comment', '// comment', '/* comment only */'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Which of these is not a JS primitive?',
    options: ['number', 'undefined', 'float', 'boolean'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Create a function named myFunction:',
    options: [
      'function myFunction() {}',
      'def myFunction() {}',
      'func myFunction() {}',
      'function: myFunction() {}',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'Call a function named myFunction:',
    options: ['call myFunction()', 'myFunction()', 'execute myFunction', 'run(myFunction)'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Correct if statement:',
    options: ['if i = 5 then', 'if (i == 5) {}', 'if i == 5 {}', 'if i = 5 {}'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Assignment operator is:',
    options: ['*', '=', '==', '==='],
    answerIndex: 1,
  ),
  _Question(
    title: 'Convert JSON string to object:',
    options: ['JSON.convert()', 'JSON.stringify()', 'JSON.parse()', 'Object.parse()'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Loop 5 times:',
    options: [
      'for (i <= 5; i++)',
      'for (let i = 0; i < 5; i++)',
      'repeat (5) {}',
      'loop i=1 to 5',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'Add item to end of array:',
    options: ['push()', 'pop()', 'shift()', 'unshift()'],
    answerIndex: 0,
  ),
  _Question(
    title: 'Strict equality operator:',
    options: ['=', '==', '===', '!='],
    answerIndex: 2,
  ),
  _Question(
    title: 'typeof null returns:',
    options: ['"null"', '"object"', '"undefined"', '"number"'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Declare a constant:',
    options: ['let PI = 3.14', 'var PI = 3.14', 'const PI = 3.14', 'fixed PI = 3.14'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Handle errors with:',
    options: ['catch/throw', 'try/catch', 'error/handle', 'resolve/reject'],
    answerIndex: 1,
  ),
  _Question(
    title: 'map() does what?',
    options: [
      'Filters elements',
      'Transforms each element and returns a new array',
      'Sorts elements',
      'Mutates original array only',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'Template literal syntax:',
    options: [
      "'Hello \${name}'",
      '"Hello \${name}"',
      '`Hello \${name}`',
      r'$(Hello ${name})',
    ],
    answerIndex: 2,
  ),
  _Question(
    title: 'Block-scoped declarations:',
    options: ['var', 'let', 'const', 'both let and const'],
    answerIndex: 3,
  ),
  _Question(
    title: 'NaN stands for:',
    options: ['Not a Null', 'Not a Number', 'Null and None', 'Negative Number'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Shallow clone an object:',
    options: ['clone(obj)', 'Object.assign({}, obj)', 'Object.copy(obj)', 'obj.clone()'],
    answerIndex: 1,
  ),
  _Question(
    title: 'Arrow functions:',
    options: [
      'Have their own this',
      'Cannot be anonymous',
      'Use lexical this from surrounding scope',
      'Require the function keyword',
    ],
    answerIndex: 2,
  ),
];
