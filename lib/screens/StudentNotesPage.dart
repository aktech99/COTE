import 'package:cote/screens/PDFViewerPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class StudentNotesPage extends StatelessWidget {
  const StudentNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the custom Firestore database with ID "cote"
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "cote",
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Student - View Notes")),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('notes').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final title = note['title'];
              final url = note['url'];

              return ListTile(
                title: Text(title),
                onTap: () => _viewPDF(context, url),
              );
            },
          );
        },
      ),
    );
  }

  // Function to view PDF in a new page
  void _viewPDF(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerPage(url: url),
      ),
    );
  }
}
