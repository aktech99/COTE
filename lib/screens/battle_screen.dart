import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final String noteId;
  final String noteUrl;
  final String teamCode;
  final DateTime startTime;

  const BattleScreen({
    super.key,
    required this.noteId,
    required this.noteUrl,
    required this.teamCode,
    required this.startTime,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  List<Map<String, dynamic>> questions = [];
  Map<int, int?> selectedAnswers = {};
  int remainingSeconds = 60;
  Timer? timer;
  bool isLoading = true;
  String errorMessage = '';

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

  void _startTimer() {
    if (!mounted) return;
    
    final now = DateTime.now();
    int elapsed = now.difference(widget.startTime).inSeconds;
    remainingSeconds = max(0, 60 - elapsed);

    if (remainingSeconds <= 0) {
      _submit();
      return;
    }

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();
        _submit();
      }
    });
  }

  Future<void> _generateQuizFromStoredText() async {
    try {
      // Get the stored extracted text from Firestore
      final querySnapshot = await db
          .collection('notes')
          .where('url', isEqualTo: widget.noteUrl)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Document not found');
      }

      final doc = querySnapshot.docs.first;
      final String extractedText = doc['extractedText'];

      if (extractedText.isEmpty) {
        throw Exception('No extracted text found');
      }

      // Generate MCQs from the stored text
      await _generateMCQs(extractedText);

      if (!mounted) return;
      
      setState(() => isLoading = false);
      _startTimer(); // Start timer after questions are ready
    } catch (e) {
      print("Error generating quiz: $e");
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        errorMessage = "Failed to generate quiz: ${e.toString()}";
      });
    }
  }

  Future<void> _generateMCQs(String text) async {
    try {
      const apiKey = "AIzaSyAw1u_V1Kfb-p-aU68lbGEBkB_LNBQmao4";
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final truncatedText = text.length > 30000 ? text.substring(0, 30000) : text;

      final prompt = """
Generate 5 multiple-choice questions from this text. Format:
Q1: [Question]
A: [Option 1]
B: [Option 2]
C: [Option 3] [CORRECT]
D: [Option 4]

$truncatedText
""";

      final res = await model.generateContent([Content.text(prompt)]);
      final raw = res.text ?? "";
      
      if (raw.isEmpty) {
        throw Exception("Generated no content from Gemini");
      }
      
      final parsed = _parseMCQs(raw);
      
      if (parsed.isEmpty) {
        throw Exception("Failed to parse questions from Gemini response");
      }
      
      if (!mounted) return;
      
      setState(() {
        questions = parsed;
        for (int i = 0; i < questions.length; i++) {
          selectedAnswers[i] = null;
        }
      });
    } catch (e) {
      print("Error generating MCQs: $e");
      rethrow;
    }
  }

  List<Map<String, dynamic>> _parseMCQs(String raw) {
    final List<Map<String, dynamic>> output = [];
    
    final pattern = RegExp(r'Q\d+:|Question \d+:');
    final matches = pattern.allMatches(raw).toList();
    
    if (matches.isEmpty) {
      return _tryParseAsOneQuestion(raw);
    }
    
    for (int i = 0; i < matches.length; i++) {
      final startIndex = matches[i].start;
      final endIndex = i < matches.length - 1 ? matches[i + 1].start : raw.length;
      final block = raw.substring(startIndex, endIndex).trim();
      
      try {
        final questionStartIndex = block.indexOf(':') + 1;
        if (questionStartIndex <= 0) continue;
        
        final lines = block.substring(questionStartIndex).trim().split('\n');
        if (lines.isEmpty) continue;
        
        final question = lines[0].trim();
        List<String> options = [];
        int correct = -1;

        for (int j = 1; j < lines.length; j++) {
          final line = lines[j].trim();
          if (line.isEmpty) continue;
          
          final optionMatch = RegExp(r'^([A-D])[\s:\.\)]+(.+?)(\s*$$CORRECT$$)?$').firstMatch(line);
          
          if (optionMatch != null) {
            final text = optionMatch.group(2)!.trim();
            options.add(text);
            if (line.contains('[CORRECT]')) {
              correct = options.length - 1;
            }
          }
        }

        if (correct == -1 && options.length == 4) {
          for (int j = 0; j < options.length; j++) {
            if (options[j].contains('✓') || options[j].contains('*') || options[j].contains('(correct)')) {
              options[j] = options[j].replaceAll('✓', '').replaceAll('*', '').replaceAll('(correct)', '').trim();
              correct = j;
              break;
            }
          }
        }
        
        if (correct == -1 && options.length == 4) {
          correct = 0;
        }

        if (options.length == 4 && question.isNotEmpty) {
          output.add({
            'question': question,
            'options': options,
            'correctAnswer': correct,
          });
        }
      } catch (e) {
        print("Error parsing question block: $e");
        continue;
      }
    }

    return output;
  }
  
  List<Map<String, dynamic>> _tryParseAsOneQuestion(String raw) {
    final lines = raw.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    
    final question = lines[0].trim();
    List<String> options = [];
    int correct = -1;
    
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      final optionMatch = RegExp(r'^([A-D])[\s:\.\)]+(.+?)(\s*$$CORRECT$$)?$').firstMatch(line);
      
      if (optionMatch != null) {
        final text = optionMatch.group(2)!.trim();
        options.add(text);
        if (line.contains('[CORRECT]')) {
          correct = options.length - 1;
        }
      }
    }
    
    if (correct == -1 && options.length == 4) {
      correct = 0;
    }
    
    if (options.length == 4 && question.isNotEmpty) {
      return [{
        'question': question,
        'options': options,
        'correctAnswer': correct,
      }];
    }
    
    return [];
  }

  void _submit() {
    timer?.cancel();

    final results = questions.asMap().entries.map((entry) {
      final index = entry.key;
      final q = entry.value;
      return {
        'question': q['question'],
        'options': q['options'],
        'correctAnswer': q['correctAnswer'],
        'selectedAnswer': selectedAnswers[index],
      };
    }).toList();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: results),
        ),
      );
    }
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Battle"),
        actions: [
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "$remainingSeconds s",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = '';
                            });
                            _generateQuizFromStoredText();
                          },
                          child: const Text("Try Again"),
                        ),
                      ],
                    ),
                  ),
                )
              : questions.isEmpty
                  ? const Center(child: Text("No questions could be generated"))
                  : ListView.builder(
                      itemCount: questions.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Q${index + 1}: ${q['question']}", 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  )
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(q['options'].length, (i) {
                                  final letter = String.fromCharCode(65 + i); // A, B, C, D
                                  return RadioListTile<int>(
                                    value: i,
                                    groupValue: selectedAnswers[index],
                                    title: Text("$letter. ${q['options'][i]}"),
                                    dense: true,
                                    onChanged: (val) {
                                      setState(() {
                                        selectedAnswers[index] = val;
                                      });
                                    },
                                  );
                                })
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: !isLoading && errorMessage.isEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Submit Now",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}