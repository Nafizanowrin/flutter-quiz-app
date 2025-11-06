import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Purpose: This class helps store and fetch quiz scores using SharedPreferences.
// Each topic (like HTML, JavaScript, React) is saved with its score and total.
class QuizScoreStore {
  // The key used to identify the stored quiz data in SharedPreferences.
  static const String _scoresKey = 'quiz_scores';

  /// Saves a quiz score for a specific topic.
  /// Stores the score, total questions, and a timestamp of when it was saved.
  static Future<void> saveScore(String topic, int score, int total) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey) ?? '{}';
      final scores = jsonDecode(scoresJson) as Map<String, dynamic>;

      scores[topic] = {
        'score': score,
        'total': total,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_scoresKey, jsonEncode(scores));
    } catch (_) {
      // If any error occurs, skip saving but don’t crash the app.
    }
  }

  /// Retrieves the saved score for a specific quiz topic.
  /// Returns null if no score is found.
  static Future<Map<String, dynamic>?> getScore(String topic) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey) ?? '{}';
      final scores = jsonDecode(scoresJson) as Map<String, dynamic>;
      return scores[topic] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Returns all saved quiz scores from local storage.
  /// Returns a map where each topic name maps to its score data.
  static Future<Map<String, Map<String, dynamic>>> getAllScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scoresJson = prefs.getString(_scoresKey) ?? '{}';
      final scores = jsonDecode(scoresJson) as Map<String, dynamic>;

      final result = <String, Map<String, dynamic>>{};
      scores.forEach((topic, data) {
        if (data is Map<String, dynamic>) result[topic] = data;
      });

      return result;
    } catch (_) {
      // If something goes wrong, return an empty list of scores.
      return {};
    }
  }

  /// Deletes all saved quiz scores from storage.
  /// Used when resetting the app or clearing progress.
  static Future<void> clearAllScores() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scoresKey);
    } catch (_) {
      // If deletion fails, ignore but app continues running.
    }
  }

  /// Returns a readable version of a quiz score like "8/10".
  /// If no score exists for the topic, returns "Not Rate".
  static Future<String> getFormattedScore(String topic) async {
    final scoreData = await getScore(topic);
    if (scoreData == null) return 'Not Rate';

    final score = scoreData['score'] as int? ?? 0;
    final total = scoreData['total'] as int? ?? 0;

    return '$score/$total';
  }

  // ---------- Attempt History (append-only) ----------

  /// Append a finished attempt to history (newest-first).
  static Future<void> saveAttempt(
      String topic,
      int score,
      int total, {
        required int finishedAtMillis,
        required int takenSeconds,
        required bool timedOut,
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'quiz_history_$topic';
      final List<String> list = prefs.getStringList(key) ?? [];
      final entry = jsonEncode({
        'score': score,
        'total': total,
        'at': finishedAtMillis, // epoch millis
        'secs': takenSeconds,   // duration in seconds
        'timedOut': timedOut,   // true if auto-finalized
      });
      // newest first
      list.insert(0, entry);
      await prefs.setStringList(key, list);
    } catch (_) {
      // ignore
    }
  }

  /// Read the most recent attempts for a topic (default up to 5).
  static Future<List<Map<String, dynamic>>> getAttempts(String topic, {int limit = 5}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'quiz_history_$topic';
      final List<String> list = prefs.getStringList(key) ?? [];
      final out = <Map<String, dynamic>>[];
      for (final s in list.take(limit)) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          out.add(m);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}

// Functionality:  saves a score with topic, total, and time of completion.
// - getScore(): retrieves one topic’s score.
// - getAllScores(): gets all saved topics and their scores.
// - clearAllScores(): deletes all saved score data.
// - getFormattedScore(): shows score in "score/total" format for display.
//
// used:
// - In the quiz pages to save results after a quiz finishes.
// - In the home or score summary pages to show past scores.
//
// SharedPreferences:
// - Works like simple local key-value storage.
// - Saves small data on the user’s device (no internet needed).
