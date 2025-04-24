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