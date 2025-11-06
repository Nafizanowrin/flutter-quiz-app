import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'pages/login.dart';
import 'pages/signup.dart';
import 'pages/home.dart';
import 'pages/splash.dart';
import 'pages/profile.dart';
import 'pages/score_board.dart';
import 'pages/html_quiz.dart';
import 'pages/javascript_quiz.dart';
import 'pages/react_quiz.dart';
import 'services/sound_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global audio context tuned for short UI sounds on real devices
  final audioContext = AudioContext(
    android: AudioContextAndroid(
      usageType: AndroidUsageType.game,           // works on many OEMs
      contentType: AndroidContentType.music,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      isSpeakerphoneOn: false,
      stayAwake: false,
    ),
    iOS: AudioContextIOS(
      // playback allows mixWithOthers; required if one set that option
      category: AVAudioSessionCategory.playback,
      options: {AVAudioSessionOptions.mixWithOthers},
    ),
  );
  await AudioPlayer.global.setAudioContext(audioContext);

  // Preload the click audio into memory to avoid first-play lag & path issues.
  await SoundPlayer.warmUp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Authentication App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.white,
      ),
      // SplashPage checks token and redirects.
      home: const SplashPage(),
      // Central route table
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/score-board': (context) => const ScoreBoardPage(),
        '/quiz-html': (context) => const HtmlQuizPage(),
        '/quiz-javascript': (context) => const JavascriptQuizPage(),
        '/quiz-react': (context) => const ReactQuizPage(),
      },
    );
  }
}
