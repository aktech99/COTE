// ExtractTextPage.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_core/firebase_core.dart';

class ExtractTextPage extends StatefulWidget {
  final String url;

  const ExtractTextPage({Key? key, required this.url}) : super(key: key);

  @override
  State<ExtractTextPage> createState() => _ExtractTextPageState();
}

class _ExtractTextPageState extends State<ExtractTextPage> {
  List<Map<String, dynamic>> generatedQuestions = [];
  List<int?> selectedAnswers = [];
  bool isLoading = true;
  final String geminiApiKey = "AIzaSyAw1u_V1Kfb-p-aU68lbGEBkB_LNBQmao4";

  // Get reference to the custom Firestore database
  final db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  @override
  void initState() {
    super.initState();
    _generateQuizFromStoredText();
  }

  Future<void> _generateQuizFromStoredText() async {
    try {
      final querySnapshot = await db
          .collection('notes')
          .where('url', isEqualTo: widget.url)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final String extractedText = doc['extractedText'];

        if (extractedText.isNotEmpty) {
          await _generateMCQs(extractedText);
        } else {
          throw Exception('No extracted text found');
        }
      } else {
        throw Exception('Document not found');
      }
    } catch (e) {
      print('Error generating quiz: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating quiz: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _generateMCQs(String extractedText) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      final prompt = """Generate 5 multiple-choice questions (MCQs) with 4 options each based on the following text. 
      For each question, clearly indicate which option is the correct answer by marking it with [CORRECT].
      Format the output as follows:
      Q1: [Question text]
      A: [Option 1]
      B: [Option 2]
      C: [Option 3] [CORRECT]
      D: [Option 4]
      
      TEXT: $extractedText""";

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final generatedText = response.text;

      if (generatedText != null && generatedText.isNotEmpty) {
        List<Map<String, dynamic>> questions = _parseQuestions(generatedText);
        setState(() {
          generatedQuestions = questions;
          selectedAnswers = List.filled(questions.length, null);
        });
      }
    } catch (e) {
      print('Error generating MCQs: $e');
      setState(() {
        generatedQuestions = [];
      });
    }
  }

  List<Map<String, dynamic>> _parseQuestions(String text) {
    List<Map<String, dynamic>> questions = [];
    try {
      final questionBlocks = text.split(RegExp(r'Q\d+:')).where((s) => s.trim().isNotEmpty).toList();
      
      for (var block in questionBlocks) {
        final questionLines = block.trim().split('\n');
        final questionText = questionLines[0].trim();
        
        List<String> options = [];
        int correctAnswerIndex = -1;
        
        for (int i = 1; i < questionLines.length; i++) {
          if (questionLines[i].trim().isEmpty) continue;
          
          final optionMatch = RegExp(r'^([A-D]):\s*(.+)$').firstMatch(questionLines[i].trim());
          if (optionMatch != null) {
            final optionText = optionMatch.group(2)!.replaceAll('[CORRECT]', '').trim();
            options.add(optionText);
            
            if (questionLines[i].contains('[CORRECT]')) {
              correctAnswerIndex = options.length - 1;
            }
          }
        }
        
        if (options.length >= 2 && correctAnswerIndex >= 0) {
          questions.add({
            'question': questionText,
            'options': options,
            'correctAnswer': correctAnswerIndex,
          });
        }
      }
    } catch (e) {
      print('Error in question parsing: $e');
    }
    return questions;
  }

  void _onOptionSelected(int questionIndex, int answerIndex) {
    setState(() {
      selectedAnswers[questionIndex] = answerIndex;
    });
  }

  void _submitQuiz() {
    int score = 0;
    for (int i = 0; i < generatedQuestions.length; i++) {
      if (selectedAnswers[i] == generatedQuestions[i]['correctAnswer']) {
        score++;
      }
    }

    // Navigate back to StudentDashboard with score
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/StudentDashboard',
      (route) => false,
      arguments: {'score': score, 'total': generatedQuestions.length},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : generatedQuestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("No questions found. Please try again."),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Go Back"),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Answer the following questions:",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: generatedQuestions.length,
                          itemBuilder: (context, index) {
                            final question = generatedQuestions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Question ${index + 1}: ${question['question']}",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 10),
                                    ...List.generate(
                                      question['options'].length,
                                      (optionIndex) => ListTile(
                                        title: Text(question['options'][optionIndex]),
                                        leading: Radio<int>(
                                          value: optionIndex,
                                          groupValue: selectedAnswers[index],
                                          onChanged: (value) {
                                            _onOptionSelected(index, value!);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitQuiz,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: const Text("Submit Quiz"),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}