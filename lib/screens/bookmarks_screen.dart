import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  List<DocumentSnapshot> bookmarkedShorts = [];
  List<DocumentSnapshot> bookmarkedNotes = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final userDoc = await firestore.collection('users').doc(user!.uid).get();
    final bookmarks = userDoc.data()?['bookmarks'] ?? {'shorts': [], 'notes': []};

    final shortIds = List<String>.from(bookmarks['shorts'] ?? []);
    final noteIds = List<String>.from(bookmarks['notes'] ?? []);

    final shortsSnap = await firestore
        .collection('shorts')
        .where(FieldPath.documentId, whereIn: shortIds.isEmpty ? ['_'] : shortIds)
        .get();

    final notesSnap = await firestore
        .collection('notes')
        .where(FieldPath.documentId, whereIn: noteIds.isEmpty ? ['_'] : noteIds)
        .get();

    setState(() {
      bookmarkedShorts = shortsSnap.docs;
      bookmarkedNotes = notesSnap.docs;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bookmarks")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text("📹 Bookmarked Shorts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...bookmarkedShorts.map((doc) {
                  return ListTile(
                    leading: const Icon(Icons.play_circle_fill),
                    title: Text("Short: ${doc.id}"),
                    subtitle: Text(doc['url']),
                    onTap: () {
                      // Optionally navigate to short player
                    },
                  );
                }),
                const SizedBox(height: 20),
                const Text("📚 Bookmarked Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...bookmarkedNotes.map((doc) {
                  return ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(doc['title'] ?? 'Untitled'),
                    subtitle: Text("Subject: ${doc['subject'] ?? 'Unknown'}"),
                    onTap: () {
                      // Optionally navigate to PDF viewer
                    },
                  );
                }),
              ],
            ),
    );
  }
}
