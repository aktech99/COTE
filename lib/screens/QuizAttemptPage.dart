import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizAttemptPage extends StatefulWidget {
  final QueryDocumentSnapshot quizData;

  const QuizAttemptPage({super.key, required this.quizData});

  @override
  State<QuizAttemptPage> createState() => _QuizAttemptPageState();
}

class _QuizAttemptPageState extends State<QuizAttemptPage> {
  int currentQuestionIndex = 0;
  int score = 0;
  List<int?> selectedAnswers = [];

  @override
  void initState() {
    super.initState();
    selectedAnswers = List<int?>.filled(widget.quizData['questions'].length, null);
  }

  void submitQuiz() {
    final questions = widget.quizData['questions'];
    int finalScore = 0;

    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]['answerIndex']) {
        finalScore++;
      }
    }

    setState(() {
      score = finalScore;
    });

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Quiz Completed"),
        content: Text("Your Score: $score / ${questions.length}"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to quiz list
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.quizData['questions'];
    final currentQuestion = questions[currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.quizData['title'])),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Q${currentQuestionIndex + 1}: ${currentQuestion['question']}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...List.generate(currentQuestion['options'].length, (index) {
              return RadioListTile<int>(
                value: index,
                groupValue: selectedAnswers[currentQuestionIndex],
                onChanged: (value) {
                  setState(() {
                    selectedAnswers[currentQuestionIndex] = value!;
                  });
                },
                title: Text(currentQuestion['options'][index]),
              );
            }),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currentQuestionIndex > 0)
                  ElevatedButton(
                    onPressed: () {
                      setState(() => currentQuestionIndex--);
                    },
                    child: const Text("Previous"),
                  ),
                ElevatedButton(
                  onPressed: currentQuestionIndex < questions.length - 1
                      ? () => setState(() => currentQuestionIndex++)
                      : submitQuiz,
                  child: Text(currentQuestionIndex < questions.length - 1 ? "Next" : "Submit"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
