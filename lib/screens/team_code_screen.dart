import 'dart:async'; // Add this import for StreamSubscription
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'battle_screen.dart';

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
  bool isWaiting = false;
  StreamSubscription<DocumentSnapshot>? _battleSubscription;

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
      final ref = firestore.collection('quizBattles').doc(code);
      final doc = await ref.get();

      if (doc.exists) {
        final data = doc.data()!;
        List players = List<String>.from(data['players'] ?? []);
        
        if (players.contains(uid)) {
          // User already joined this battle
          print("User already in this battle");
        } else if (players.length < 2) {
          // Add user to existing battle
          players.add(uid);
          await ref.update({
            'players': players,
            'playerStatus.$uid': 'joined',
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
        // Create new battle
        await ref.set({
          'noteId': widget.noteId,
          'noteUrl': widget.noteUrl,
          'teamCode': code,
          'players': [uid],
          'playerStatus': {uid: 'joined'},
          'started': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Listen for battle start
      if (mounted) {
        setState(() {
          isWaiting = true;
          isJoining = false;
        });
      }

      _listenForBattleStart(ref);
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

  void _listenForBattleStart(DocumentReference ref) {
    _battleSubscription?.cancel();
    _battleSubscription = ref.snapshots().listen((battleDoc) async {
      if (!battleDoc.exists || !mounted) return;
      
      try {
        final data = battleDoc.data() as Map<String, dynamic>;
        List players = List<String>.from(data['players'] ?? []);
        final started = data['started'] ?? false;

        // Auto-start when 2 players have joined
        if (players.length == 2 && !started) {
          await ref.update({
            'started': true,
            'startTime': FieldValue.serverTimestamp(),
          });
        }

        // Navigate to battle screen when ready
        if (started && data['startTime'] != null) {
          final startTime = (data['startTime'] as Timestamp).toDate();
          
          // Cancel subscription before navigating
          await _battleSubscription?.cancel();
          _battleSubscription = null;
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BattleScreen(
                  noteId: widget.noteId,
                  noteUrl: widget.noteUrl,
                  teamCode: ref.id,
                  startTime: startTime,
                ),
              ),
            );
          }
        }
      } catch (e) {
        print("Error in battle listener: $e");
      }
    }, onError: (error) {
      print("Error listening to battle updates: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $error')),
        );
      }
    });
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
            const SizedBox(height: 32),
            if (isWaiting)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    "Waiting for another player to join team ${_teamCodeController.text}...",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}