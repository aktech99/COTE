import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? _userData;
  final TextEditingController _subjectController = TextEditingController();
  bool _isLoading = true;

  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final doc = await firestore.collection('users').doc(_currentUser!.uid).get();
    setState(() {
      _userData = doc.data();
      _isLoading = false;
    });
  }

  Future<void> _addSubject() async {
    final newSubject = _subjectController.text.trim();
    if (newSubject.isEmpty) return;

    final updatedSubjects = [..._userData!['subjects'], newSubject];
    await firestore.collection('users').doc(_currentUser!.uid).update({
      'subjects': updatedSubjects,
    });
    _subjectController.clear();
    _loadUserProfile();
  }

  Future<void> _removeSubject(String subject) async {
    if (_userData!['role'] == 'teacher') return;

    final updatedSubjects = List<String>.from(_userData!['subjects']);
    updatedSubjects.remove(subject);

    await firestore.collection('users').doc(_currentUser!.uid).update({
      'subjects': updatedSubjects,
    });
    _loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: ${_userData!['email']}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text("Role: ${_userData!['role']}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            const Text("Subjects:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: List<Widget>.from(
                _userData!['subjects'].map<Widget>(
                  (subject) => Chip(
                    label: Text(subject),
                    deleteIcon: _userData!['role'] == 'student'
                        ? const Icon(Icons.close)
                        : null,
                    onDeleted: _userData!['role'] == 'student'
                        ? () => _removeSubject(subject)
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(hintText: "Add new subject"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addSubject,
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
