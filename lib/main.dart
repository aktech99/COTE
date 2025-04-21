import 'package:cote/screens/PlaceholdeScreen.dart';
import 'package:cote/screens/StudentDashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/student_home.dart';
import 'screens/teacher_home.dart';
import 'screens/subject_selection_screen.dart';

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
        '/studentHome': (context) => StudentHome(),
        '/teacherHome': (context) => TeacherHome(),
        '/subjectSelection': (context) => SubjectSelectionScreen(role: 'student'),
        '/studentDashboard': (context) => const StudentDashboard(),
        '/studentNotes': (context) => const PlaceholderScreen(title: "Notes Page"), // Replace with your actual Notes page
        '/quizBattle': (context) => const PlaceholderScreen(title: "Quiz Battle Page"), // Replace with real screen later
      },
    );
  }
}
