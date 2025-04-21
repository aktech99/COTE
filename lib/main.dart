import 'package:cote/screens/StudentDashboard.dart';
import 'package:cote/screens/StudentQuizPage.dart';
import 'package:cote/screens/TeacherHome.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/student_home.dart';
import 'screens/TeacherHome.dart';
import 'screens/subject_selection_screen.dart';
import 'screens/TeacherNotesPage.dart';
import 'screens/StudentNotesPage.dart';
import 'screens/ExtractTextPage.dart'; // Import the ExtractTextPage where text extraction happens.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Manual setup
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'COTE',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/StudentDashboard': (context) => const StudentDashboard(),
        '/student_home': (context) => const StudentHome(),
        '/StudentNotesPage': (context) => const StudentNotesPage(),
        '/StudentQuizPage': (context) => const StudentQuizPage(),
        '/TeacherHome': (context) => const TeacherHome(),
        '/TeacherNotesPage': (context) => const TeacherNotesPage(),
        '/subject_selection_screen': (context) => SubjectSelectionScreen(role: 'student'),
        '/ExtractTextPage': (context) => ExtractTextPage(url: ''), // Added this route to navigate to text extraction page
      },
    );
  }
}
