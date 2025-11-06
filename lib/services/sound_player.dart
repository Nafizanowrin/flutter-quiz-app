import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Plays short UI sounds (button clicks) from assets (MP3 only).
class SoundPlayer {
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  // Existing cache for click
  static Uint8List? _clickBytes;

  // New caches for additional sounds
  static Uint8List? _correctBytes;
  static Uint8List? _wrongBytes;
  static Uint8List? _partyBytes;

  /// Preload bytes to remove first-play delay. (kept as-is: preloads click)
  static Future<void> warmUp() async {
    try {
      if (_clickBytes == null) {
        final bd = await rootBundle.load('sounds/click.mp3');
        _clickBytes = bd.buffer.asUint8List();
      }
      await _player.setVolume(1.0);
    } catch (_) {}
  }

  /// Small helper to safely play a cached byte source.
  static Future<void> _playBytes(Uint8List bytes) async {
    await _player.stop(); // ensure fresh playback
    await _player.play(BytesSource(bytes));
  }

  /// Play the click sound (very reliable across Android/iOS).
  static Future<void> click() async {
    try {
      _clickBytes ??= (await rootBundle.load('sounds/click.mp3')).buffer.asUint8List();
      await _playBytes(_clickBytes!);
    } catch (_) {
      // ignore any small playback errors
    }
  }

  /// Play when the selected option is correct.
  static Future<void> correct() async {
    try {
      _correctBytes ??= (await rootBundle.load('sounds/correct.mp3')).buffer.asUint8List();
      await _playBytes(_correctBytes!);
    } catch (_) {}
  }

  /// Play when the selected option is wrong.
  static Future<void> wrong() async {
    try {
      _wrongBytes ??= (await rootBundle.load('sounds/wrong.mp3')).buffer.asUint8List();
      await _playBytes(_wrongBytes!);
    } catch (_) {}
  }

  // Celebration sound on score page.
  static Future<void> party() async {
    try {
      final bd = await rootBundle.load('sounds/party.mp3');
      await _player.stop();
      await _player.play(BytesSource(bd.buffer.asUint8List()));
    } catch (_) {}
  }


  static Future<void> dispose() async {
    try {
      await _player.stop();
      await _player.release();
    } catch (_) {}
  }
}



// import 'dart:typed_data';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:flutter/services.dart' show rootBundle;
//
// /// Plays short UI sounds (button clicks) from assets (MP3 only).
// class SoundPlayer {
//   static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
//   static Uint8List? _clickBytes;
//
//   /// Preload bytes to remove first-play delay.
//   static Future<void> warmUp() async {
//     try {
//       if (_clickBytes == null) {
//         final bd = await rootBundle.load('sounds/click.mp3');
//         _clickBytes = bd.buffer.asUint8List();
//       }
//       await _player.setVolume(1.0);
//     } catch (_) {}
//   }
//
//   /// Play the click sound (very reliable across Android/iOS).
//   static Future<void> click() async {
//     try {
//       await _player.stop(); // ensure fresh playback
//       _clickBytes ??= (await rootBundle.load('sounds/click.mp3')).buffer.asUint8List();
//       await _player.play(BytesSource(_clickBytes!));
//     } catch (e) {
//       // ignore any small playback errors
//     }
//   }
//
//   static Future<void> dispose() async {
//     try {
//       await _player.stop();
//       await _player.release();
//     } catch (_) {}
//   }
// }
