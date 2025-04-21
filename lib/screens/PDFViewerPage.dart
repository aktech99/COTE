import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class PDFViewerPage extends StatefulWidget {
  final String url;
  const PDFViewerPage({super.key, required this.url});

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  String? localPath;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    downloadAndSavePDF();
  }

  Future<void> downloadAndSavePDF() async {
    try {
      final response = await http.get(Uri.parse(widget.url));
      final bytes = response.bodyBytes;

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/temp.pdf');

      await file.writeAsBytes(bytes);
      setState(() {
        localPath = file.path;
        isLoading = false;
      });
    } catch (e) {
      print("Error downloading PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to open PDF")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("View PDF")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : PDFView(
              filePath: localPath!,
            ),
    );
  }
}
