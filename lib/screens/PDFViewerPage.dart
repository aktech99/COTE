// PDFViewerPage.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PDFViewerPage extends StatefulWidget {
  final String url;
  final File cachedFile;

  const PDFViewerPage({
    Key? key,
    required this.url,
    required this.cachedFile,
  }) : super(key: key);

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  int currentPage = 0;
  int? totalPages;
  PDFViewController? pdfViewController;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("PDF Viewer"),
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.cachedFile.path,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            defaultPage: currentPage,
            onViewCreated: (PDFViewController controller) {
              setState(() {
                pdfViewController = controller;
              });
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                currentPage = page ?? 0;
                totalPages = total;
              });
            },
            onRender: (pages) {
              setState(() {
                totalPages = pages;
              });
            },
            onError: (error) {
              print("Error loading PDF: $error");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error loading PDF: $error'),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
          ),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: totalPages != null
          ? Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: currentPage > 0
                        ? () {
                            pdfViewController?.setPage(currentPage - 1);
                          }
                        : null,
                  ),
                  Text(
                    'Page ${currentPage + 1} of $totalPages',
                    style: const TextStyle(fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: currentPage < (totalPages! - 1)
                        ? () {
                            pdfViewController?.setPage(currentPage + 1);
                          }
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}