import 'package:flutter/material.dart';
import 'pages/login.dart';
import 'pages/signup.dart';
import 'pages/home.dart';
import 'pages/splash.dart';
import 'pages/profile.dart';
import 'pages/score_board.dart';
import 'pages/html_quiz.dart';
import 'pages/javascript_quiz.dart';
import 'pages/react_quiz.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App-wide settings
      title: 'Authentication App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.white,
      ),

      // First screen shown. SplashPage checks token and redirects.
      home: const SplashPage(),

      // Central route table. Keep paths consistent with Navigator.pushNamed calls.
      // If you add a new screen, register it here.
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/score-board': (context) => const ScoreBoardPage(),
        '/quiz-html': (context) => const HtmlQuizPage(),
        '/quiz-javascript' : (context) => const JavascriptQuizPage(),
        '/quiz-react' : (context) => const ReactQuizPage(),
      },
    );
  }
}
