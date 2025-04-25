import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ready_screen.dart';

class TeamCodeScreen extends StatefulWidget {
  final String noteId;
  final String noteUrl;

  const TeamCodeScreen({
    super.key,
    required this.noteId,
    required this.noteUrl,
  });

  @override
  State<TeamCodeScreen> createState() => _TeamCodeScreenState();
}

class _TeamCodeScreenState extends State<TeamCodeScreen> {
  final TextEditingController _teamCodeController = TextEditingController();
  final uid = FirebaseAuth.instance.currentUser!.uid;
  late final FirebaseFirestore firestore;
  
  bool isJoining = false;
  StreamSubscription<QuerySnapshot>? _battleSubscription;

  @override
  void initState() {
    super.initState();
    try {
      firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );
    } catch (e) {
      firestore = FirebaseFirestore.instance;
      print("Using default Firestore instance: $e");
    }
  }

  Future<void> _joinOrCreateBattle() async {
    final code = _teamCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team code')),
      );
      return;
    }

    setState(() {
      isJoining = true;
    });

    try {
      // Generate quiz questions BEFORE creating the battle
      final questions = await _generateQuizQuestions();

      // First, check if a battle with this team code already exists
      final querySnapshot = await firestore
          .collection('quizBattles')
          .where('teamCode', isEqualTo: code)
          .where('started', isEqualTo: false)  // Only find battles that haven't started
          .get();
      
      String battleId;
      
      if (querySnapshot.docs.isNotEmpty) {
        // Join existing battle
        final doc = querySnapshot.docs.first;
        battleId = doc.id;
        final data = doc.data();
        List players = List<String>.from(data['players'] ?? []);
        
        if (players.contains(uid)) {
          // User already joined this battle
          print("User already in this battle");
        } else if (players.length < 2) {
          // Add user to existing battle
          players.add(uid);
          Map<String, bool> playerReady = Map<String, bool>.from(data['playerReady'] ?? {});
          playerReady[uid] = false;
          
          await firestore.collection('quizBattles').doc(battleId).update({
            'players': players,
            'playerReady': playerReady,
            'questions': questions,  // Store pre-generated questions
          });
        } else {
          // Battle is full
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This team is full!')),
            );
            setState(() {
              isJoining = false;
            });
          }
          return;
        }
      } else {
        // Create new battle with auto-generated ID
        final battleRef = firestore.collection('quizBattles').doc();
        battleId = battleRef.id;
        
        await battleRef.set({
          'noteId': widget.noteId,
          'noteUrl': widget.noteUrl,
          'teamCode': code,
          'players': [uid],
          'playerReady': {uid: false},
          'started': false,
          'startTime': null,
          'completed': false,
          'winner': null,
          'playerData': {},
          'questions': questions,  // Store pre-generated questions
        });
      }

      // Navigate to the ReadyScreen with pre-generated questions
      if (mounted) {
        setState(() {
          isJoining = false;
        });
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ReadyScreen(
              noteId: widget.noteId,
              noteUrl: widget.noteUrl,
              teamCode: code,
              battleId: battleId,
              preGeneratedQuestions: questions,  // Pass pre-generated questions
            ),
          ),
        );
      }
    } catch (e) {
      print("Error joining/creating battle: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() {
          isJoining = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _generateQuizQuestions() async {
    try {
      // Get the stored extracted text from Firestore
      final querySnapshot = await firestore
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

      // Generate MCQs using Gemini
      const apiKey = "AIzaSyAw1u_V1Kfb-p-aU68lbGEBkB_LNBQmao4";
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final truncatedText = extractedText.length > 30000 
          ? extractedText.substring(0, 30000) 
          : extractedText;

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
      
      return parsed;
    } catch (e) {
      print("Error generating quiz questions: $e");
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

  @override
  void dispose() {
    _teamCodeController.dispose();
    _battleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Team Code")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _teamCodeController,
              decoration: const InputDecoration(
                labelText: "Enter or Create Team Code",
                hintText: "Enter a unique code to start or join a quiz",
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _joinOrCreateBattle(),
            ),
            const SizedBox(height: 24),
            if (isJoining)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _joinOrCreateBattle,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text("Start Quiz Battle", style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}