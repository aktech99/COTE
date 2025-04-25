import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'result_screen.dart';

class BattleScreen extends StatefulWidget {
  final String noteId;
  final String noteUrl;
  final String teamCode;
  final String battleId;
  final DateTime startTime;
  final List<Map<String, dynamic>>? preGeneratedQuestions;

  const BattleScreen({
    super.key,
    required this.noteId,
    required this.noteUrl,
    required this.teamCode,
    required this.battleId,
    required this.startTime,
    this.preGeneratedQuestions,
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
  final uid = FirebaseAuth.instance.currentUser!.uid;

  // Get reference to the custom Firestore database
  late final FirebaseFirestore db;
  StreamSubscription<DocumentSnapshot>? _battleSubscription;

  @override
  void initState() {
    super.initState();
    try {
      db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );
    } catch (e) {
      db = FirebaseFirestore.instance;
      print("Using default Firestore instance: $e");
    }
    
    // Use pre-generated questions if available
    if (widget.preGeneratedQuestions != null) {
      setState(() {
        questions = widget.preGeneratedQuestions!;
        isLoading = false;
      });
      _startTimer();
    } else {
      // Fallback to original generation method
      _generateQuizFromStoredText();
    }
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
  
    try {
      // Split the raw text into potential question blocks
      final questionBlocks = raw.split(RegExp(r'Q\d+:|Question \d+:'));
      
      for (var block in questionBlocks.skip(1)) {  // Skip first empty element
        final lines = block.trim().split('\n');
        
        if (lines.isEmpty) continue;
        
        // Extract question
        final question = lines[0].trim();
        final options = <String>[];
        int correctAnswerIndex = -1;
        
        // Parse options
        for (int i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          // Extract option text, handling various formats
          final optionMatch = RegExp(r'^([A-D])[\s:\.\)]+(.+?)(\s*$$CORRECT$$)?$').firstMatch(line);
          
          if (optionMatch != null) {
            final optionText = optionMatch.group(2)!.trim();
            options.add(optionText);
            
            // Check for explicit correct answer marking
            if (line.contains('[CORRECT]') || 
                line.contains('(correct)') || 
                line.contains('✓')) {
              correctAnswerIndex = options.length - 1;
            }
          }
          
          // Limit to 4 options
          if (options.length == 4) break;
        }
        
        // If no explicit correct answer found, default to first option
        if (correctAnswerIndex == -1 && options.length == 4) {
          correctAnswerIndex = 0;
        }
        
        // Only add if we have a valid question and 4 options
        if (question.isNotEmpty && 
            options.length == 4 && 
            correctAnswerIndex != -1) {
          output.add({
            'question': question,
            'options': options,
            'correctAnswer': correctAnswerIndex,
          });
        }
      }
    } catch (e) {
      print("Error parsing MCQs: $e");
    }
    
    // If no questions parsed, return a default set of questions
    return output.isNotEmpty 
      ? output 
      : [
          {
            'question': 'No questions could be generated',
            'options': ['A', 'B', 'C', 'D'],
            'correctAnswer': 0,
          }
        ];
  }

  Future<void> _submit() async {
    timer?.cancel();

    // Calculate score
    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      if (selectedAnswers[i] == questions[i]['correctAnswer']) {
        correctCount++;
      }
    }
    
    // Update player data in the battle document
    try {
      final battleRef = db.collection('quizBattles').doc(widget.battleId);
      
      await battleRef.update({
        'playerData.$uid': {
          'score': correctCount,
          'completedAt': FieldValue.serverTimestamp(),
          'answers': selectedAnswers.map((key, value) => MapEntry(key.toString(), value)),
          'submitted': true,  // Add a submitted flag
        },
      });

      // Listen for opponent's submission
      _waitForOpponentSubmission();
    } catch (e) {
      print("Error updating player data: $e");
    }
  }

  void _waitForOpponentSubmission() {
    final battleRef = db.collection('quizBattles').doc(widget.battleId);
    
    _battleSubscription = battleRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data()!;
      final Map<String, dynamic> playerData = Map<String, dynamic>.from(data['playerData'] ?? {});
      final List<String> players = List<String>.from(data['players'] ?? []);
      
      // Find opponent ID
      String? opponentId;
      for (final playerId in players) {
        if (playerId != uid) {
          opponentId = playerId;
          break;
        }
      }
      
      // Check if both players have submitted
      bool allSubmitted = players.every((playerId) => 
        playerData[playerId] != null && 
        playerData[playerId]['submitted'] == true
      );
      
      if (allSubmitted) {
        _battleSubscription?.cancel();
        
        // Prepare result data
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

        // Navigate to ResultScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                result: results, 
                battleId: widget.battleId,
                uid: uid,
              ),
            ),
          );
        }
      }
    }, onError: (error) {
      print("Error waiting for opponent submission: $error");
    });
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  void dispose() {
    timer?.cancel();
    _battleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Battle"),
        automaticallyImplyLeading: false,
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