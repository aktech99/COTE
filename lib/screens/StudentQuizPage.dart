import 'package:cote/screens/QuizAttemptPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentQuizPage extends StatelessWidget {
  const StudentQuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Quizzes")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('quizzes').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final quizzes = snapshot.data!.docs;

          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              final title = quiz['title'];

              return ListTile(
                title: Text(title),
                trailing: const Icon(Icons.play_arrow),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizAttemptPage(quizData: quiz),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
