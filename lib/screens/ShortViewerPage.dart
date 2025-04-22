import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ShortViewerPage extends StatefulWidget {
  final int initialIndex;
  final List<QueryDocumentSnapshot> docs;

  const ShortViewerPage({
    super.key,
    required this.initialIndex,
    required this.docs,
  });

  @override
  State<ShortViewerPage> createState() => _ShortViewerPageState();
}

class _ShortViewerPageState extends State<ShortViewerPage> {
  late PageController _pageController;
  final Map<int, VideoPlayerController> _videoControllers = {};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeControllerAt(_currentIndex);
    _initializeControllerAt(_currentIndex - 1);
    _initializeControllerAt(_currentIndex + 1);
  }

  void _initializeControllerAt(int index) {
    if (index < 0 || index >= widget.docs.length || _videoControllers.containsKey(index)) return;
    final url = widget.docs[index]['url'];
final controller = VideoPlayerController.network(url);

controller.initialize().then((_) {
  controller.setLooping(true);
  if (index == _currentIndex) controller.play();

  setState(() {}); // To refresh the UI after initialization
}).catchError((e) {
  print('Video init error: $e');
});

_videoControllers[index] = controller;


  }

  void _disposeControllerAt(int index) {
    if (_videoControllers.containsKey(index)) {
      _videoControllers[index]!.dispose();
      _videoControllers.remove(index);
    }
  }

  @override
  void dispose() {
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    if (newIndex == _currentIndex) return;

    _videoControllers[_currentIndex]?.pause();

    setState(() {
      _currentIndex = newIndex;
    });

    _initializeControllerAt(_currentIndex);
    _initializeControllerAt(_currentIndex - 1);
    _initializeControllerAt(_currentIndex + 1);

    _videoControllers[_currentIndex]?.play();

    // Dispose far away videos to save memory
    for (int i in _videoControllers.keys.toList()) {
      if ((i - _currentIndex).abs() > 1) {
        _disposeControllerAt(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Reels"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.docs.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final controller = _videoControllers[index];

          if (controller == null || !controller.value.isInitialized) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
              });
            },
            child: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
