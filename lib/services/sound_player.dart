import 'package:audioplayers/audioplayers.dart';

/// Small helper to play short UI sounds from assets.
/// Keeps a single low-latency player so it feels instant.
class SoundPlayer {
  static final AudioPlayer _player = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop); // don't loop

  /// Call once on app start (optional) to warm up the player.
  static Future<void> warmUp() async {
    try {
      // A quick no-op to initialize the engine earlier helps reduce first-play delay.
      await _player.setVolume(1.0);
    } catch (_) {}
  }

  /// Play a short click sound. Non-blocking.
  static Future<void> click() async {
    try {
      // Use AssetSource for assets declared in pubspec.
      await _player.play(AssetSource('assets/sounds/click.mp3'));
    } catch (_) {
      // Ignore sound errors to avoid breaking UI actions.
    }
  }

  /// If you ever need to clean up explicitly.
  static Future<void> dispose() async {
    try {
      await _player.stop();
      await _player.release();
    } catch (_) {}
  }
}
