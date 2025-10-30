import 'dart:async';
import 'package:flutter/material.dart';
import '../services/quiz_score_store.dart';
import '../services/quiz_progress_store.dart';
import '../services/sound_player.dart';

class ReactQuizPage extends StatefulWidget {
  const ReactQuizPage({super.key});

  @override
  State<ReactQuizPage> createState() => _ReactQuizPageState();
}

class _ReactQuizPageState extends State<ReactQuizPage> with WidgetsBindingObserver {
  // Topic key for saving and loading progress
  static const String _topic = 'React';

  // Quiz state: current question index and selected answer index
  int currentIndex = 0;
  int? selectedIndex;
  bool showCorrectAnswer = false;

  // Store answers per question (-1 means skipped)
  final List<int?> _answers = List<int?>.filled(_questions.length, null);

  // Per-question countdown timer, penalties, and total spent seconds
  Timer? _tick;
  int _remaining = 12;
  int _penalties = 0;
  int _spent = 0;

  // Used to measure total quiz duration
  int? _startMillis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Record start time for total duration calculation
    _startMillis = DateTime.now().millisecondsSinceEpoch;

    // Load any previous progress and start timer
    _loadSavedProgress().whenComplete(_startTimer);
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Save progress automatically when app is backgrounded or paused
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  // Save progress (answers, penalties, remaining time, etc.)
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

  // Restore saved progress if available
  Future<void> _loadSavedProgress() async {
    final full = await QuizProgressStore.loadProgressFull(_topic);
    if (full != null) {
      var idx = full.$1;
      List<int?> ans = List<int?>.from(full.$2);
      var rem = full.$3;
      var pen = full.$5;

      // Adjust answer list length if question count changed
      if (ans.length != _questions.length) {
        if (ans.length < _questions.length) {
          ans = [...ans, ...List<int?>.filled(_questions.length - ans.length, null)];
        } else {
          ans = ans.sublist(0, _questions.length);
        }
      }

      // Clamp saved index into valid range
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
        _spent = 0;
      });
      return;
    }

    // Handle legacy saved data format
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
      _spent = 0;
    });
  }

  // Start timer to count down per question
  void _startTimer() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        _spent++;
      });
      if (_remaining <= 0) {
        _onTimeoutAdvance();
      }
    });
  }

  // Reset question timer
  void _resetTimer() {
    setState(() => _remaining = 12);
    _startTimer();
  }

  // When time runs out, move to next question or finish
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
      _finishQuiz();
    }
  }

  // Record user’s answer selection
  void _recordSelection(int optionIndex) async {
    // If this question is already answered, ignore extra taps
    if (_answers[currentIndex] != null) return;

    // Play a short tap sound; ignore any errors so UI never blocks
    try {
      // Assuming you added a small helper like SoundPlayer.click()
      // If you haven't yet, you can comment this out temporarily.
      await SoundPlayer.click();
    } catch (_) {}

    // Save the chosen option and reveal the correct/incorrect coloring
    setState(() {
      selectedIndex = optionIndex;
      _answers[currentIndex] = optionIndex;
      showCorrectAnswer = true;
    });

    // Track correct answers for scoring if the choice was right
    if (optionIndex == _questions[currentIndex].answerIndex) {
      await QuizProgressStore.bumpCorrectCount(_topic);
    }

    // Stop the per-question timer and persist progress
    _tick?.cancel();
    await _saveProgress();
  }


  // Handle next or finish button
  Future<void> _goNextOrFinish() async {
    // play click sound for button; ignore any errors so UI never blocks
    try {
      await SoundPlayer.click();
    } catch (_) {}

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


  // Complete quiz and record results
  Future<void> _finishQuiz() async {
    _tick?.cancel();
    final endMillis = DateTime.now().millisecondsSinceEpoch;
    final totalTakenSec = ((endMillis - (_startMillis ?? endMillis)) / 1000).round();

    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      final ans = _answers[i];
      if (ans != null && ans >= 0 && ans == _questions[i].answerIndex) {
        correct++;
      }
    }

    // Compute score after applying penalties
    final score = (correct - _penalties).clamp(0, _questions.length);

    await QuizScoreStore.saveScore(_topic, score, _questions.length);
    await QuizProgressStore.saveTimeTaken(_topic, totalTakenSec);
    await QuizProgressStore.clearProgress(_topic);

    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/score-board',
      arguments: {'score': score, 'total': _questions.length, 'topic': _topic},
    );
  }

  // Build user interface for the quiz
  @override
  Widget build(BuildContext context) {
    final question = _questions[currentIndex];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top section with back and home buttons and quiz title
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
                      'React',
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

            // Main quiz card containing question and answers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with timer
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Question', style: TextStyle(color: Color(0xFF0F469A), fontWeight: FontWeight.w600)),
                      Text('${_remaining}s', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Question: ${currentIndex + 1}/20',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(question.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // Display answer options
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

            // Navigation buttons for next and finish
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

// Widget for rendering each answer option
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

    // Determine color scheme based on selection and correctness
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
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

// Question data model for the quiz
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
    title: 'What is React?',
    options: [
      'A full-stack framework',
      'A JavaScript library for building UIs',
      'A CSS preprocessor',
      'A server-side runtime',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'Who maintains React?',
    options: ['Google', 'Facebook (Meta)', 'Microsoft', 'Twitter'],
    answerIndex: 1,
  ),
  _Question(
    title: 'What is JSX?',
    options: [
      'A CSS-in-JS library',
      'A syntax extension that lets you write HTML-like code in JS',
      'A JSON schema for components',
      'A server-side templating engine',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which hook is used to add state to a function component?',
    options: ['useRef', 'useEffect', 'useState', 'useMemo'],
    answerIndex: 2,
  ),
  _Question(
    title: 'Which hook runs after every render by default?',
    options: ['useEffect', 'useCallback', 'useReducer', 'useLayoutEffect'],
    answerIndex: 0,
  ),
  _Question(
    title: 'What prop is required when rendering a list of components?',
    options: ['name', 'id', 'key', 'index'],
    answerIndex: 2,
  ),
  _Question(
    title: 'What is the correct way to pass props to a component?',
    options: [
      '<User(props)>',
      '<User name="Alex" />',
      '<User: name="Alex" />',
      'User(name="Alex")',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'How do you create a component in React?',
    options: [
      'function Button() { return <button/> }',
      'new Component(Button)',
      'component Button() {}',
      'class Button()',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'What does lifting state up mean?',
    options: [
      'Moving state from parent to child',
      'Using global variables',
      'Sharing state by moving it to the nearest common ancestor',
      'Persisting state to localStorage',
    ],
    answerIndex: 2,
  ),
  _Question(
    title: 'How do you handle side effects in React?',
    options: ['useEffect', 'useState', 'useMemo', 'useId'],
    answerIndex: 0,
  ),
  _Question(
    title: 'What is the purpose of useMemo?',
    options: [
      'To memoize values to avoid expensive recalculations',
      'To memoize components only',
      'To defer effects',
      'To handle refs',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'How do you prevent a component from re-rendering unnecessarily?',
    options: ['useState', 'React.memo', 'setState in render', 'Inline functions'],
    answerIndex: 1,
  ),
  _Question(
    title: 'What does the Context API solve?',
    options: [
      'DOM manipulation',
      'Prop drilling by providing global-ish data',
      'Routing between pages',
      'Server-side rendering',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'What is the purpose of the useEffect hook in React?',
    options: [
      'To handle side effects such as data fetching or DOM updates',
      'To define application routes',
      'To store local component state',
      'To create reusable context providers',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'Which library is commonly used for routing in React?',
    options: ['React Router', 'Next.js', 'Express', 'Axios'],
    answerIndex: 0,
  ),
  _Question(
    title: 'What does useRef provide?',
    options: [
      'Mutable container that persists for the full lifetime of the component',
      'A state setter',
      'A memoized function',
      'A way to fetch data',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'How do you conditionally render elements?',
    options: [
      'Using if statements inside JSX directly',
      'Using ternary operators or logical && in JSX',
      'Using CSS only',
      'You cannot do conditional rendering',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which statement about keys is true?',
    options: [
      'Keys should be unique among siblings',
      'Keys must be globally unique',
      'Indexes are always safe as keys',
      'Keys are optional for lists',
    ],
    answerIndex: 0,
  ),
  _Question(
    title: 'What is a controlled component?',
    options: [
      'A component that manages its own state internally only',
      'A component whose form data is handled by React state',
      'A component controlled by Redux only',
      'A component that is disabled',
    ],
    answerIndex: 1,
  ),
  _Question(
    title: 'Which hook would you use for complex state logic with multiple sub-values?',
    options: ['useState', 'useEffect', 'useReducer', 'useMemo'],
    answerIndex: 2,
  ),
];
