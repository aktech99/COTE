import 'package:cote/screens/teacher_shorts_upload.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/splash_screen.dart'; // ✅ New splash screen
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/student_home.dart';
import 'screens/StudentDashboard.dart';
import 'screens/TeacherHome.dart';
import 'screens/subject_selection_screen.dart';
import 'screens/TeacherNotesPage.dart';
import 'screens/StudentNotesPage.dart';
import 'screens/StudentQuizPage.dart';
import 'screens/ExtractTextPage.dart';
import 'screens/profile_screen.dart';
import 'screens/bookmarks_screen.dart';

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
      initialRoute: '/', // ✅ Start from splash
      routes: {
        '/': (context) => const SplashScreen(), // ✅ Splash screen checks login & role
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
        '/ExtractTextPage': (context) => ExtractTextPage(url: ''),
        '/profile': (context) => const ProfileScreen(),
        '/bookmarks': (context) => const BookmarksScreen(),
        '/uploadShort': (context) => const TeacherShortsUpload(),
      },
    );
  }
}
