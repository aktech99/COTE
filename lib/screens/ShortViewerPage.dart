// short_viewer_page.dart
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
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeControllerAt(_currentIndex);
    if (_currentIndex > 0) {
      _initializeControllerAt(_currentIndex - 1);
    }
    if (_currentIndex < widget.docs.length - 1) {
      _initializeControllerAt(_currentIndex + 1);
    }
  }

  void _initializeControllerAt(int index) {
    if (index < 0 || 
        index >= widget.docs.length || 
        _videoControllers.containsKey(index)) return;

    final data = widget.docs[index].data() as Map<String, dynamic>;
    final url = data['url'] as String;
    
    print('Initializing video at index $index with URL: $url');

    try {
      final controller = VideoPlayerController.network(
        url,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      _videoControllers[index] = controller;

      controller.initialize().then((_) {
        print('Video initialized successfully at index $index');
        if (mounted) {
          setState(() {
            controller.setLooping(true);
            if (index == _currentIndex) {
              controller.play();
              print('Playing video at index $index');
            }
          });
        }
      }).catchError((e) {
        print('Video init error at index $index: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading video: $e')),
          );
        }
      });
    } catch (e) {
      print('Controller creation error at index $index: $e');
    }
  }

  void _disposeControllerAt(int index) {
    if (_videoControllers.containsKey(index)) {
      print('Disposing controller at index $index');
      _videoControllers[index]!.dispose();
      _videoControllers.remove(index);
    }
  }

  @override
  void dispose() {
    print('Disposing all controllers');
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    if (newIndex == _currentIndex) return;

    print('Page changed from $_currentIndex to $newIndex');
    
    // Pause current video
    _videoControllers[_currentIndex]?.pause();

    setState(() {
      _currentIndex = newIndex;
      _showControls = false;
    });

    // Initialize and play new video
    _initializeControllerAt(newIndex);
    _videoControllers[newIndex]?.play();

    // Preload adjacent videos
    if (newIndex > 0) {
      _initializeControllerAt(newIndex - 1);
    }
    if (newIndex < widget.docs.length - 1) {
      _initializeControllerAt(newIndex + 1);
    }

    // Dispose far away controllers
    for (int i in _videoControllers.keys.toList()) {
      if ((i - newIndex).abs() > 1) {
        _disposeControllerAt(i);
      }
    }
  }

  void _togglePlayPause() {
    final controller = _videoControllers[_currentIndex];
    if (controller == null) return;

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showControls = false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
          final data = widget.docs[index].data() as Map<String, dynamic>;
          final description = data['description'] as String? ?? '';

          if (controller == null || !controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return GestureDetector(
            onTap: _toggleControls,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),

                // Play/Pause overlay
                if (_showControls)
                  Container(
                    color: Colors.black26,
                    child: Center(
                      child: IconButton(
                        iconSize: 64,
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  ),

                // Description overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}