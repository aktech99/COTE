import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class ResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> result;
  final String battleId;
  final String uid;

  const ResultScreen({
    super.key,
    required this.result,
    required this.battleId,
    required this.uid,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final FirebaseFirestore firestore;
  bool isLoading = true;
  bool isBattleComplete = false;
  Map<String, dynamic>? opponentData;
  String? opponentId;
  String? battleResult;
  StreamSubscription<DocumentSnapshot>? _battleSubscription;

  // Detailed result tracking
  List<Map<String, dynamic>> detailedResults = [];
  int playerScore = 0;
  int opponentScore = 0;

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
    
    _checkBattleResults();
  }

  void _checkBattleResults() {
    final battleRef = firestore.collection('quizBattles').doc(widget.battleId);
    
    _battleSubscription = battleRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data()!;
      final Map<String, dynamic> playerData = Map<String, dynamic>.from(data['playerData'] ?? {});
      final List<String> players = List<String>.from(data['players'] ?? []);
      
      // Ensure both players have submitted
      bool allSubmitted = players.every((playerId) => 
        playerData[playerId] != null && 
        playerData[playerId]['submitted'] == true
      );
      
      if (!allSubmitted) {
        return;  // Wait until both players submit
      }
      
      // Find opponent ID
      for (final playerId in players) {
        if (playerId != widget.uid) {
          opponentId = playerId;
          break;
        }
      }
      
      // Get player and opponent scores
      playerScore = playerData[widget.uid]?['score'] ?? 0;
      opponentScore = playerData[opponentId]?['score'] ?? 0;
      
      // Prepare detailed results
      detailedResults = widget.result.map((q) {
        bool isCorrect = q['selectedAnswer'] == q['correctAnswer'];
        return {
          'question': q['question'],
          'userAnswer': q['selectedAnswer'] != null 
              ? q['options'][q['selectedAnswer']] 
              : 'Not Answered',
          'correctAnswer': q['options'][q['correctAnswer']],
          'isCorrect': isCorrect,
        };
      }).toList();
      
      // Determine battle result
      String battleResultTemp;
      if (playerScore > opponentScore) {
        battleResultTemp = 'Win';
      } else if (playerScore < opponentScore) {
        battleResultTemp = 'Lose';
      } else {
        battleResultTemp = 'Draw';
      }
      
      // Update user stats and battle result
      await _updateBattleResultAndStats(battleResultTemp);
      
      if (mounted) {
        setState(() {
          battleResult = battleResultTemp;
          opponentData = playerData[opponentId];
          isLoading = false;
          isBattleComplete = true;
        });
      }
    }, onError: (error) {
      print("Error checking battle results: $error");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  Future<void> _updateBattleResultAndStats(String battleResultTemp) async {
    try {
      final userRef = firestore.collection('users').doc(widget.uid);
      final opponentRef = firestore.collection('users').doc(opponentId);

      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final opponentDoc = await transaction.get(opponentRef);

        if (!userDoc.exists || !opponentDoc.exists) return;

        final userCurrentRating = userDoc.data()?['quizRating'] ?? 1200;
        final opponentCurrentRating = opponentDoc.data()?['quizRating'] ?? 1200;

        // ELO Rating calculation
        const k = 32;  // K-factor
        double gameResult;
        if (battleResultTemp == 'Win') {
          gameResult = 1.0;
        } else if (battleResultTemp == 'Lose') {
          gameResult = 0.0;
        } else {
          gameResult = 0.5;
        }

        final expectedScore = 1 / (1 + pow(10, (opponentCurrentRating - userCurrentRating) / 400));
        final newRating = userCurrentRating + k * (gameResult - expectedScore);

        // Update user stats
        transaction.update(userRef, {
          'quizzesTaken': FieldValue.increment(1),
          'quizzesWon': battleResultTemp == 'Win' ? FieldValue.increment(1) : FieldValue.increment(0),
          'quizzesLost': battleResultTemp == 'Lose' ? FieldValue.increment(1) : FieldValue.increment(0),
          'quizzesDraw': battleResultTemp == 'Draw' ? FieldValue.increment(1) : FieldValue.increment(0),
          'quizRating': newRating.round(),
          'quizBattlesPlayed': FieldValue.increment(1),
          'quizBattlesWon': battleResultTemp == 'Win' ? FieldValue.increment(1) : FieldValue.increment(0),
          'quizBattlesLost': battleResultTemp == 'Lose' ? FieldValue.increment(1) : FieldValue.increment(0),
        });

        // Update battle document
        final battleRef = firestore.collection('quizBattles').doc(widget.battleId);
        transaction.update(battleRef, {
          'completed': true,
          'winner': battleResultTemp == 'Win' 
              ? widget.uid 
              : (battleResultTemp == 'Lose' ? opponentId : null),
          'finalScores': {
            widget.uid: playerScore,
            opponentId: opponentScore,
          },
        });
      });
    } catch (e) {
      print("Error updating battle result and stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Battle Results"),
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Overall Result Section
                _buildOverallResultSection(),
                
                // Detailed Quiz Results
                _buildDetailedResultsList(),
                
                // Navigation Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Text("Back to Home"),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverallResultSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _getResultColor(),
      child: Column(
        children: [
          Text(
            battleResult == 'Win' ? "Victory!" : 
            (battleResult == 'Lose' ? "Defeat" : "Draw"),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildScoreCard("You", playerScore, detailedResults.length),
              _buildScoreCard("Opponent", opponentScore, detailedResults.length),
            ],
          ),
        ],
      ),
    );
  }

  Color _getResultColor() {
    if (battleResult == 'Win') return Colors.green;
    if (battleResult == 'Lose') return Colors.red;
    return Colors.grey;
  }

  Widget _buildScoreCard(String title, int score, int totalQuestions) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "$score/$totalQuestions",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedResultsList() {
    return ExpansionTile(
      title: const Text(
        "Detailed Quiz Results",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      children: detailedResults.map((result) {
        return ListTile(
          title: Text(result['question']),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Your Answer: ${result['userAnswer']}"),
              Text("Correct Answer: ${result['correctAnswer']}"),
            ],
          ),
          trailing: Icon(
            result['isCorrect'] ? Icons.check_circle : Icons.cancel,
            color: result['isCorrect'] ? Colors.green : Colors.red,
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _battleSubscription?.cancel();
    super.dispose();
  }
}