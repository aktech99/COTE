import 'package:cote/screens/StudentShortsViewer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:video_player/video_player.dart';


class StudentShortsGridPage extends StatefulWidget {
  const StudentShortsGridPage({super.key});

  @override
  State<StudentShortsGridPage> createState() => _StudentShortsGridPageState();
}

class _StudentShortsGridPageState extends State<StudentShortsGridPage> {
  late FirebaseFirestore db;
  List<Map<String, dynamic>> _videos = [];

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
    final snapshot = await db.collection('shorts').get();
    final videoList = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      _videos = videoList;
    });
  }
  Future<VideoPlayerController> _initializeVideoController(String url) async {
  final controller = VideoPlayerController.network(url);
  await controller.initialize();
  return controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Shorts")),
      body: _videos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
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
                          videos: _videos, shorts: [],
                        ),
                      ),
                    );
                  },
                  child: FutureBuilder<VideoPlayerController>(
                  future: _initializeVideoController(video['url']),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.done) {
      final controller = snapshot.data!;
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  },
),

                );
              },
            ),
    );
  }
}
