import 'package:cote/screens/ShortViewerPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'ShortViewerPage.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: "cote",
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Shorts"),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by tags...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Shorts Grid
          Expanded(
            child: StreamBuilder(
              stream: db.collection('shorts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snapshot.data!.docs;
                final filteredDocs = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final tags = List<String>.from(data['tags'] ?? []);
                        return tags.any((tag) =>
                            tag.toLowerCase().contains(_searchQuery));
                      }).toList();

                // Debug print
                print('Number of shorts found: ${filteredDocs.length}');
                for (var doc in filteredDocs) {
                  final data = doc.data();
                  print('Short data:');
                  print('Video URL: ${data['url']}');
                  print('Thumbnail URL: ${data['thumbnailUrl']}');
                  print('Description: ${data['description']}');
                  print('Tags: ${data['tags']}');
                }

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No videos found with matching tags',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 9/16,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final thumbnailUrl = data['thumbnailUrl'] as String?;
                    final description = data['description'] as String? ?? '';
                    final tags = List<String>.from(data['tags'] ?? []);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShortViewerPage(
                              initialIndex: index,
                              docs: filteredDocs,
                            ),
                          ),
                        );
                      },
                      child: Container(
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
                              // Thumbnail
                              thumbnailUrl != null
                                  ? CachedNetworkImage(
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
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        color: Colors.grey[800],
                                        child: const Icon(
                                          Icons.video_library,
                                          color: Colors.white60,
                                          size: 40,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey[800],
                                      child: const Icon(
                                        Icons.video_library,
                                        color: Colors.white60,
                                        size: 40,
                                      ),
                                    ),

                              // Gradient overlay
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

                              // Description and Tags
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (description.isNotEmpty)
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (tags.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            children: tags.map((tag) => Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '#$tag',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            )).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}