import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:video_player/video_player.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final List<VideoPlayerController> _controllers = [];
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex != _currentIndex && newIndex < _controllers.length) {
      setState(() {
        // Pause the previous video
        if (_currentIndex < _controllers.length) {
          _controllers[_currentIndex].pause();
        }
        // Play the current video
        _currentIndex = newIndex;
        _controllers[_currentIndex].play();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

Widget buildVideo(String url, int index) {
  // Check if controller already exists
  if (index >= _controllers.length) {
    final controller = VideoPlayerController.network(url);
    _controllers.add(controller);
    controller.initialize().then((_) {
      // Only play the current video
      if (index == _currentIndex) {
        controller.play();
      }
      controller.setLooping(true);
      // Force refresh to show the video
      if (mounted) setState(() {});
    }).catchError((e) {
      // Handle any initialization errors
      print('Error initializing video: $e');
    });
  }

  final controller = _controllers[index];
  
  return controller.value.isInitialized
      ? GestureDetector(
          onTap: () {
            setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            });
          },
          child: Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio, // Use native aspect ratio
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        )
      : const Center(child: CircularProgressIndicator(color: Colors.white));
}


  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "cote",
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Student Shorts"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: db.collection('shorts').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final docs = snapshot.data!.docs;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final url = docs[index]['url'];
              return buildVideo(url, index);
            },
          );
        },
      ),
    );
  }
}