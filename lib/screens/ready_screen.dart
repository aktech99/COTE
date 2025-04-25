import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'battle_screen.dart';

class ReadyScreen extends StatefulWidget {
  final String noteId;
  final String noteUrl;
  final String teamCode;
  final String battleId;
  final List<Map<String, dynamic>>? preGeneratedQuestions;

  const ReadyScreen({
    super.key,
    required this.noteId,
    required this.noteUrl,
    required this.teamCode,
    required this.battleId,
    this.preGeneratedQuestions,
  });

  @override
  State<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends State<ReadyScreen> {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  late final FirebaseFirestore firestore;
  bool isReady = false;
  bool isOpponentReady = false;
  String? opponentId;
  StreamSubscription<DocumentSnapshot>? _battleSubscription;
  bool isNavigating = false;

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
    
    _listenToBattleChanges();
  }

  void _listenToBattleChanges() {
    final battleRef = firestore.collection('quizBattles').doc(widget.battleId);
    
    _battleSubscription = battleRef.snapshots().listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      
      final data = snapshot.data()!;
      final List<String> players = List<String>.from(data['players'] ?? []);
      final Map<String, dynamic> playerReady = Map<String, dynamic>.from(data['playerReady'] ?? {});
      final bool started = data['started'] ?? false;
      
      // Find opponent ID
      for (final playerId in players) {
        if (playerId != uid) {
          opponentId = playerId;
          break;
        }
      }
      
      // Check if opponent is ready
      bool opponentReadyState = false;
      if (opponentId != null && playerReady.containsKey(opponentId)) {
        opponentReadyState = playerReady[opponentId] ?? false;
      }
      
      setState(() {
        isOpponentReady = opponentReadyState;
      });
      
      // If battle has started, navigate to BattleScreen
      if (started && data['startTime'] != null && !isNavigating) {
        final startTime = (data['startTime'] as Timestamp).toDate();
        
        _navigateToBattle(startTime);
      }
    }, onError: (error) {
      print("Error listening to battle updates: $error");
    });
  }
  
  Future<void> _setReadyStatus(bool ready) async {
    setState(() {
      isReady = ready;
    });
    
    try {
      final battleRef = firestore.collection('quizBattles').doc(widget.battleId);
      await battleRef.update({
        'playerReady.$uid': ready,
      });
      
      // Check if both players are ready and start the battle if so
      final snapshot = await battleRef.get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final Map<String, dynamic> playerReady = Map<String, dynamic>.from(data['playerReady'] ?? {});
        
        bool allReady = true;
        for (final entry in playerReady.entries) {
          if (entry.value != true) {
            allReady = false;
            break;
          }
        }
        
        if (allReady && playerReady.length >= 2) {
          await battleRef.update({
            'started': true,
            'startTime': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print("Error setting ready status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update ready status: ${e.toString()}')),
        );
      }
    }
  }
  
  void _navigateToBattle(DateTime startTime) {
    if (isNavigating) return;
    
    setState(() {
      isNavigating = true;
    });
    
    _battleSubscription?.cancel();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BattleScreen(
            noteId: widget.noteId,
            noteUrl: widget.noteUrl,
            teamCode: widget.teamCode,
            battleId: widget.battleId,
            startTime: startTime,
            preGeneratedQuestions: widget.preGeneratedQuestions,
          ),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _battleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Waiting Room"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Team Code:",
                style: TextStyle(fontSize: 16),
              ),
              Text(
                widget.teamCode,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              const Text(
                "Waiting for both players to be ready...",
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      const Text("You", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isReady ? Colors.green : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isReady ? Icons.check : Icons.hourglass_empty,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isReady ? "Ready" : "Not Ready",
                        style: TextStyle(
                          color: isReady ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 60),
                  Column(
                    children: [
                      const Text("Opponent", style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isOpponentReady ? Colors.green : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOpponentReady ? Icons.check : Icons.hourglass_empty,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOpponentReady ? "Ready" : "Not Ready",
                        style: TextStyle(
                          color: isOpponentReady ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: isReady ? null : () => _setReadyStatus(true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                child: Text(
                  isReady ? "Ready!" : "I'm Ready!",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              if (isReady)
                TextButton(
                  onPressed: () => _setReadyStatus(false),
                  child: const Text("Cancel Ready"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}