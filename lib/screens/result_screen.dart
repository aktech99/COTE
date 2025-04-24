// result_screen.dart

import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    int correct = result.where((r) => r['selectedAnswer'] == r['correctAnswer']).length;

    return Scaffold(
      appBar: AppBar(title: const Text("Quiz Results")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Your Score: $correct / ${result.length}",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...result.asMap().entries.map((entry) {
              final index = entry.key;
              final r = entry.value;
              final selected = r['selectedAnswer'];
              final correctAnswer = r['correctAnswer'];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Q${index + 1}: ${r['question']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...List.generate(r['options'].length, (i) {
                        final option = r['options'][i];
                        final isCorrect = i == correctAnswer;
                        final isSelected = i == selected;
                        return Container(
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green.shade100
                                : isSelected
                                    ? Colors.red.shade100
                                    : null,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isCorrect
                                  ? Icons.check_circle
                                  : isSelected
                                      ? Icons.cancel
                                      : Icons.circle_outlined,
                              color: isCorrect
                                  ? Colors.green
                                  : isSelected
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                            title: Text(option),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.popUntil(context, ModalRoute.withName('/StudentDashboard')),
              child: const Text("Back to Dashboard"),
            )
          ],
        ),
      ),
    );
  }
}