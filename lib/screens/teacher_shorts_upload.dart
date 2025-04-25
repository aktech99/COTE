// teacher_shorts_upload.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class TeacherShortsUpload extends StatefulWidget {
  const TeacherShortsUpload({super.key});

  @override
  State<TeacherShortsUpload> createState() => _TeacherShortsUploadState();
}

class _TeacherShortsUploadState extends State<TeacherShortsUpload> {
  bool isUploading = false;
  String? videoUrl;
  String? thumbnailUrl;
  File? thumbnailFile;
  File? videoFile;
  VideoPlayerController? _videoController;
  final descriptionController = TextEditingController();
  final tagsController = TextEditingController();

  @override
  void dispose() {
    _videoController?.dispose();
    descriptionController.dispose();
    tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      thumbnailFile = File(pickedFile.path);
    });
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final videoFile = File(pickedFile.path);
    final controller = VideoPlayerController.file(videoFile);
    
    try {
      await controller.initialize();
      await controller.seekTo(Duration.zero);
      await controller.pause();
      
      setState(() {
        this.videoFile = videoFile;
        if (_videoController != null) {
          _videoController!.dispose();
        }
        _videoController = controller;
      });
    } catch (e) {
      print('Error loading video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading video: $e")),
      );
    }
  }

  Future<void> _uploadVideo() async {
    if (thumbnailFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a thumbnail first")),
      );
      return;
    }

    if (videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a video first")),
      );
      return;
    }

    if (descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add a description")),
      );
      return;
    }

    setState(() => isUploading = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      print('Starting upload process...');

      // Upload thumbnail
      final thumbnailRef = FirebaseStorage.instance
          .ref()
          .child('shorts/thumbnails/$uid/${DateTime.now().millisecondsSinceEpoch}');
      await thumbnailRef.putFile(thumbnailFile!);
      thumbnailUrl = await thumbnailRef.getDownloadURL();
      print('Thumbnail uploaded. URL: $thumbnailUrl');

      // Upload video
      final videoRef = FirebaseStorage.instance
          .ref()
          .child('shorts/$uid/${DateTime.now().millisecondsSinceEpoch}');
      await videoRef.putFile(videoFile!);
      videoUrl = await videoRef.getDownloadURL();
      print('Video uploaded. URL: $videoUrl');

      // Convert tags string to list
      List<String> tags = tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final db = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: "cote",
      );

      await db.collection('shorts').add({
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'description': descriptionController.text,
        'tags': tags,
        'teacherId': uid,
        'uploadedAt': Timestamp.now(),
      });

      print('Data stored in Firestore successfully');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploaded successfully")),
      );

      Navigator.pop(context); // Return to TeacherHome after successful upload

    } catch (e) {
      print('Upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Short'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Preview
            Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _videoController != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                              if (!_videoController!.value.isPlaying)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: TextButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.video_library),
                        label: const Text('Select Video'),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Thumbnail selection
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: thumbnailFile != null
                  ? Image.file(thumbnailFile!, fit: BoxFit.cover)
                  : Center(
                      child: TextButton.icon(
                        onPressed: _pickThumbnail,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Select Thumbnail'),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Description field
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Enter video description...',
              ),
            ),
            const SizedBox(height: 16),

            // Tags field
            TextField(
              controller: tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                border: OutlineInputBorder(),
                hintText: 'Enter tags separated by commas...',
              ),
            ),
            const SizedBox(height: 16),

            // Upload button
            ElevatedButton.icon(
              onPressed: isUploading ? null : _uploadVideo,
              icon: const Icon(Icons.upload),
              label: Text(isUploading ? 'Uploading...' : 'Upload Video'),
            ),
          ],
        ),
      ),
    );
  }
}