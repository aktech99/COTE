import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  bool isUploading = false;
  String? videoUrl;

  Future<void> _pickAndUploadVideo() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => isUploading = true);

    final file = File(pickedFile.path);
    final filename = pickedFile.name;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final ref = FirebaseStorage.instance.ref().child('shorts/$uid/$filename');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );

      await db.collection('shorts').add({
        'url': url,
        'teacherId': uid,
        'uploadedAt': Timestamp.now(),
      });

      setState(() {
        videoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploaded successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: isUploading ? null : _pickAndUploadVideo,
              child: Text(isUploading ? 'Uploading...' : 'Upload Video'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/TeacherNotesPage');
              },
              child: const Text('Upload Notes'),
            ),
            const SizedBox(height: 16),
            if (videoUrl != null) Text('Uploaded: $videoUrl'),
          ],
        ),
      ),
    );
  }
}
