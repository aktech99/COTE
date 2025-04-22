import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

class StudentShortsViewer extends StatefulWidget {
  final List<String> shorts;
  final int initialIndex;

  const StudentShortsViewer({
    super.key,
    required this.shorts,
    required this.initialIndex, required List<Map<String, dynamic>> videos,
  });

  @override
  State<StudentShortsViewer> createState() => _StudentShortsViewerState();
}

class _StudentShortsViewerState extends State<StudentShortsViewer> {
  final List<VideoPlayerController> _controllers = [];
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
  final newIndex = _pageController.page?.round() ?? 0;

  // Avoid accessing out-of-range indexes
  if (newIndex != _currentIndex &&
      newIndex < _controllers.length &&
      _controllers[newIndex].value.isInitialized) {
    setState(() {
      if (_currentIndex < _controllers.length) {
        _controllers[_currentIndex].pause();
      }
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
    _pageController.dispose();
    super.dispose();
  }

  Widget buildVideo(String url, int index) {
    if (index >= _controllers.length) {
  final controller = VideoPlayerController.network(url);
  _controllers.add(controller);
  controller.initialize().then((_) {
    if (!mounted) return;

    setState(() {
      controller.setLooping(true);
      if (index == _currentIndex) controller.play();
    });
  }).catchError((e) {
    print("Error initializing video: $e");
  });
}


    final controller = _controllers[index];
    return controller.value.isInitialized
        ? GestureDetector(
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Shorts"),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.shorts.length,
        itemBuilder: (context, index) {
          return buildVideo(widget.shorts[index], index);
        },
      ),
    );
  }
}
