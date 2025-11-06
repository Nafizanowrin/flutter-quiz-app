import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
/// Stores and restores in-progress quiz state on the device.
/// Used by quiz pages to resume where the user left off and to
/// enforce a single global countdown across all quizzes.
class QuizProgressStore {
  // Key used to keep the shared/global deadline for all quizzes.
  static const _globalDeadlineKey = 'quiz_global_deadline';

  /// Save everything needed to resume a quiz later.
  /// - topic: quiz name (e.g., "HTML")
  /// - currentIndex: which question the user is on
  /// - answers: user selections; null = untouched, -1 = missed by timeout
  /// - remainingSeconds: seconds left on the per-question timer
  /// - lastSavedAtMillis: when we saved (for reference/diagnostics)
  /// - penalties: how many timeout penalties so far
  static Future<void> saveProgress(
      String topic,
      int currentIndex,
      List<int?> answers, {
        required int remainingSeconds,
        required int lastSavedAtMillis,
        required int penalties,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'index': currentIndex,
      'answers': answers,
      'remaining': remainingSeconds,
      'lastSavedAt': lastSavedAtMillis,
      'penalties': penalties,
    };
    await prefs.setString('progress_$topic', jsonEncode(data));
  }

  /// Lightweight restore: get just the current index and answers list.
  /// Returns null if no saved progress for this topic.
  static Future<(int, List<int?>)?> loadProgress(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('progress_$topic');
    if (str == null) return null;
    final map = jsonDecode(str);
    final idx = map['index'] as int? ?? 0;
    final ans = (map['answers'] as List?)?.cast<int?>() ?? [];
    return (idx, ans);
  }

  /// Full restore: index, answers, remaining seconds, last save time, penalties.
  /// Returns null if nothing saved for this topic.
  static Future<(int, List<int?>, int, int, int)?> loadProgressFull(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('progress_$topic');
    if (str == null) return null;
    final map = jsonDecode(str);
    final idx = map['index'] as int? ?? 0;
    final ans = (map['answers'] as List?)?.cast<int?>() ?? [];
    final remaining = map['remaining'] as int? ?? 12;
    final savedAt = map['lastSavedAt'] as int? ?? 0;
    final penalties = map['penalties'] as int? ?? 0;
    return (idx, ans, remaining, savedAt, penalties);
  }

  /// Remove saved progress for one topic (used when finishing a quiz).
  static Future<void> clearProgress(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('progress_$topic');
  }

  /// Mark a topic as finished; stores a finish timestamp (millis).
  /// You can use this to do simple "last finished at" checks if needed.
  static Future<void> markFinished(String topic, int millis) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('finished_$topic', millis);
  }

  /// List all topics that currently have saved progress.
  static Future<List<String>> topicsWithProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith('progress_'))
        .map((e) => e.substring(9))
        .toList();
  }

  /// Quick check for saved progress?
  static Future<bool> hasProgress(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('progress_$topic');
  }

  /// Read the global deadline (shared timer across all quizzes), in millis.
  static Future<int?> getGlobalDeadlineMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_globalDeadlineKey);
  }

  /// Start the global deadline if it isn't running, or return existing one.
  static Future<int> getOrStartGlobalDeadlineMillis({required double hours}) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getInt(_globalDeadlineKey);
    if (existing != null) return existing;

    final deadline = DateTime.now()
        .add(Duration(minutes: (hours * 60).round()))
        .millisecondsSinceEpoch;

    await prefs.setInt(_globalDeadlineKey, deadline);
    return deadline;
  }

  /// Clear the global deadline (used when all quizzes are finalized).
  static Future<void> clearGlobalDeadline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_globalDeadlineKey);
  }

  /// Count of correctly answered questions for a topic (for scoring).
  /// Increment by one when the user picks the right answer.
  static Future<void> bumpCorrectCount(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'correct_$topic';
    final val = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, val + 1);
  }

  /// Read the stored correct answer count for a topic.
  static Future<int> getCorrectCount(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('correct_$topic') ?? 0;
  }

  /// Clear the correct count for a topic (usually when finishing).
  static Future<void> clearCorrectCount(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('correct_$topic');
  }

  /// Save total time taken (in seconds) to finish a quiz.
  /// Used for showing duration in Recent Activity
  static Future<void> saveTimeTaken(String topic, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('time_taken_$topic', seconds);
  }

  /// Read total time taken in seconds for a topic
  static Future<int?> getTimeTakenSeconds(String topic) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('time_taken_$topic');
  }
}
