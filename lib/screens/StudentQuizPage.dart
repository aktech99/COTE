import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'team_code_screen.dart';
import 'package:firebase_core/firebase_core.dart';

class StudentQuizPage extends StatefulWidget {
  const StudentQuizPage({super.key});

  @override
  State<StudentQuizPage> createState() => _StudentQuizPageState();
}

class _StudentQuizPageState extends State<StudentQuizPage> {
  late final FirebaseFirestore firestore;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    try {
      firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );
    } catch (e) {
      // Fallback to default instance if custom instance fails
      firestore = FirebaseFirestore.instance;
      errorMessage = "Using default Firestore instance. Original error: ${e.toString()}";
      print(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Note for Quiz Battle"),
        elevation: 2,
      ),
      body: errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.amber),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          errorMessage = null;
                          try {
                            firestore = FirebaseFirestore.instanceFor(
                              app: Firebase.app(),
                              databaseId: "cote",
                            );
                          } catch (e) {
                            firestore = FirebaseFirestore.instance;
                            errorMessage = "Using default Firestore instance. Error: ${e.toString()}";
                          }
                        });
                      },
                      child: const Text("Retry Connection"),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('notes')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            "Error loading notes: ${snapshot.error}",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No notes available for quiz battles"),
                      ],
                    ),
                  );
                }

                final notes = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: notes.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final noteId = note.id;
                    final title = note['title'] ?? 'Untitled Note';
                    final noteUrl = note['url'];
                    final timestamp = note['timestamp'] as Timestamp?;
                    final dateStr = timestamp != null 
                        ? _formatDate(timestamp.toDate())
                        : 'Unknown date';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          title, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        subtitle: Text(dateStr),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TeamCodeScreen(
                                noteId: noteId,
                                noteUrl: noteUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
  
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
