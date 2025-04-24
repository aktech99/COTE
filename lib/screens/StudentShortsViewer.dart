// StudentShortsGridPage.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'StudentShortsViewer.dart';

class StudentShortsGridPage extends StatefulWidget {
  const StudentShortsGridPage({super.key});

  @override
  State<StudentShortsGridPage> createState() => _StudentShortsGridPageState();
}

class _StudentShortsGridPageState extends State<StudentShortsGridPage> {
  late FirebaseFirestore db;
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "cote",
    );
    fetchVideos();
  }

  Future<void> fetchVideos() async {
    try {
      final snapshot = await db.collection('shorts').get();
      final videoList = snapshot.docs.map((doc) {
        final data = doc.data();
        // Ensure document ID is included
        return {...data, 'id': doc.id};
      }).toList();

      setState(() {
        _videos = videoList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching videos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Shorts"),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text("No shorts available"))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.6, // Portrait aspect ratio for shorts
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentShortsViewer(
                              initialIndex: index,
                              videos: _videos,
                            ),
                          ),
                        );
                      },
                      child: VideoThumbnail(
                        videoUrl: video['url'],
                        title: video['title'] ?? 'Short #${index + 1}',
                      ),
                    );
                  },
                ),
    );
  }
}

// Add this new widget for optimized thumbnails
class VideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final String title;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a thumbnail URL or use placeholder
    // If you have actual thumbnails, replace this with your thumbnail URL
    String thumbnailUrl = videoUrl.replaceAll('.mp4', '.jpg');
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail with fade-in animation
            CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[900],
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[800],
                child: const Icon(
                  Icons.video_library,
                  color: Colors.white60,
                  size: 40,
                ),
              ),
            ),
            
            // Gradient overlay for text visibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
            ),
            
            // Play icon
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 48,
                color: Colors.white70,
              ),
            ),
            
            // Title at the bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// StudentShortsViewer.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class StudentShortsViewer extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final int initialIndex;

  const StudentShortsViewer({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<StudentShortsViewer> createState() => _StudentShortsViewerState();
}

class _StudentShortsViewerState extends State<StudentShortsViewer> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  // Store controllers in a map for better memory management
  final Map<int, VideoPlayerController> _controllers = {};
  
  // Keep track of which videos are preloaded
  final Set<int> _preloadedIndices = {};
  
  bool _showControls = false;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Initialize the first video and preload adjacent videos
    _initializeControllerAtIndex(_currentIndex);
    _preloadAdjacentVideos(_currentIndex);
    
    _pageController.addListener(_onPageChanged);
  }
  
  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? 0;
    
    if (newIndex != _currentIndex) {
      // Pause current video
      _controllers[_currentIndex]?.pause();
      
      setState(() {
        _currentIndex = newIndex;
        _showControls = false;
      });
      
      // Play new video
      if (_controllers.containsKey(newIndex)) {
        _controllers[newIndex]?.play();
      } else {
        _initializeControllerAtIndex(newIndex);
      }
      
      // Preload adjacent videos
      _preloadAdjacentVideos(newIndex);
      
      // Clean up far away controllers to save memory
      _disposeDistantControllers(newIndex);
    }
  }
  
  void _preloadAdjacentVideos(int index) {
    // Preload the next 2 videos
    for (int i = 1; i <= 2; i++) {
      final preloadIndex = index + i;
      if (preloadIndex < widget.videos.length && !_preloadedIndices.contains(preloadIndex)) {
        _preloadVideoAtIndex(preloadIndex);
      }
    }
  }
  
  void _preloadVideoAtIndex(int index) {
    if (index >= 0 && index < widget.videos.length && !_controllers.containsKey(index)) {
      _preloadedIndices.add(index);
      final videoUrl = widget.videos[index]['url'];
      
      // Create controller but don't initialize yet
      final controller = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      // Just cache it lightly - will be fully initialized when needed
      controller.setVolume(0);
      controller.initialize().then((_) {
        // Don't do anything special here, just cache the initialized controller
      });
      
      _controllers[index] = controller;
    }
  }
  
  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    
    final videoUrl = widget.videos[index]['url'];
    
    // If controller exists but not initialized, initialize it
    if (_controllers.containsKey(index)) {
      final controller = _controllers[index]!;
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      controller.setLooping(true);
      controller.setVolume(1.0);
      controller.play();
      return;
    }
    
    // Otherwise create and initialize a new controller
    final controller = VideoPlayerController.network(
      videoUrl,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    
    _controllers[index] = controller;
    
    try {
      await controller.initialize();
      if (!mounted) return;
      
      controller.setLooping(true);
      if (index == _currentIndex) {
        controller.play();
      }
      
      setState(() {}); // Refresh UI
    } catch (e) {
      print("Error initializing video $index: $e");
    }
  }
  
  void _disposeDistantControllers(int currentIndex) {
    // Keep only controllers within a certain range (e.g., ±3)
    const int keepRange = 3;
    
    final keysToRemove = _controllers.keys.where(
      (idx) => (idx - currentIndex).abs() > keepRange
    ).toList();
    
    for (final idx in keysToRemove) {
      _controllers[idx]?.dispose();
      _controllers.remove(idx);
      _preloadedIndices.remove(idx);
    }
  }
  
  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
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
      if (!_showControls) {
        // Auto-hide controls after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _pageController.dispose();
    super.dispose();
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
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          return _buildVideoPage(index);
        },
      ),
    );
  }
  
  Widget _buildVideoPage(int index) {
    final video = widget.videos[index];
    final String videoTitle = video['title'] ?? 'Short #${index + 1}';
    final String videoDescription = video['description'] ?? '';
    
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          Center(
            child: _controllers.containsKey(index) && 
                   _controllers[index]!.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controllers[index]!.value.aspectRatio,
                  child: VideoPlayer(_controllers[index]!),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
          ),
          
          // Video controls overlay
          if (_showControls)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/pause button
                  IconButton(
                    icon: Icon(
                      _controllers.containsKey(index) && 
                      _controllers[index]!.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                      size: 64,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Video progress and seek bar
                  if (_controllers.containsKey(index) && 
                      _controllers[index]!.value.isInitialized)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Slider for seeking
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white30,
                              thumbColor: Colors.white,
                              overlayColor: Colors.white24,
                            ),
                            child: Slider(
                              value: _controllers[index]!.value.position.inMilliseconds.toDouble(),
                              min: 0,
                              max: _controllers[index]!.value.duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                _controllers[index]!.seekTo(
                                  Duration(milliseconds: value.toInt()),
                                );
                              },
                            ),
                          ),
                          
                          // Duration text
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(_controllers[index]!.value.position),
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Text(
                                  _formatDuration(_controllers[index]!.value.duration),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          
          // Video info overlay
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
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    videoTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (videoDescription.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        videoDescription,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Loading indicator overlay
          if (!_controllers.containsKey(index) || 
              !_controllers[index]!.value.isInitialized)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}