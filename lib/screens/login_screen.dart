import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> login() async {
  setState(() => isLoading = true);
  try {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    final uid = credential.user?.uid;
    if (uid == null) throw Exception("User not found");

    final firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(), // ✅ manually specifying
      databaseId: "cote",  // ✅ your Firestore DB id
    );

    final doc = await firestore.collection('users').doc(uid).get();
    final role = doc.data()?['role'];

     if (role == 'student') {
  Navigator.pushReplacementNamed(context, '/StudentDashboard');
}
     else if (role == 'teacher') {
      Navigator.pushReplacementNamed(context, '/TeacherHome');
    } else {
      throw Exception("Role missing or invalid");
    }

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Login failed: $e")),
    );
  } finally {
    setState(() => isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : login,
              child: isLoading ? const CircularProgressIndicator() : const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}
