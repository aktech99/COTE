import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class SubjectSelectionScreen extends StatefulWidget {
  final String role;
  const SubjectSelectionScreen({super.key, required this.role});

  @override
  State<SubjectSelectionScreen> createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen> {
  final List<String> allSubjects = [
    'Math', 'Physics', 'Chemistry', 'Biology', 'English', 'CS', 'Economics'
  ];

  final selectedSubjects = <String>{};
  bool isLoading = false;

  Future<void> submitSubjects() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found")),
      );
      return;
    }

    if (selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one subject")),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      ).collection('users').doc(uid).update({
        'subjects': selectedSubjects.toList(),
      });

      Navigator.pushReplacementNamed(
        context,
        widget.role == "teacher" ? '/TeacherHome' : '/StudentDashboard',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving subjects: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Select Subjects (${widget.role})")),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: allSubjects.map((subject) {
                return CheckboxListTile(
                  title: Text(subject),
                  value: selectedSubjects.contains(subject),
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        selectedSubjects.add(subject);
                      } else {
                        selectedSubjects.remove(subject);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: isLoading ? null : submitSubjects,
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Continue"),
          ),
        ],
      ),
    );
  }
}
