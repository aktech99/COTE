import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class TeacherNotesPage extends StatefulWidget {
  const TeacherNotesPage({super.key});

  @override
  _TeacherNotesPageState createState() => _TeacherNotesPageState();
}

class _TeacherNotesPageState extends State<TeacherNotesPage> {
  bool _isUploading = false;

  // Get reference to the custom Firestore database
  final db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  // Function to handle PDF upload
  Future<void> _uploadPDF() async {
    final XTypeGroup typeGroup = XTypeGroup(label: 'pdf', extensions: ['pdf']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      final String fileName = file.name;
      final Uint8List fileBytes = await file.readAsBytes();

      setState(() {
        _isUploading = true;
      });

      try {
        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance.ref().child('notes/$fileName');
        await ref.putData(fileBytes);

        // Get the download URL of the uploaded file
        final url = await ref.getDownloadURL();

        // Print the URL for debugging
        print("File URL: $url");

        // Write metadata to Firestore
        await db.collection('notes').add({
          'title': fileName,
          'url': url,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } catch (e) {
        print("Error uploading file: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher - Upload Notes")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadPDF,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Upload PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
