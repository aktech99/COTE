// teacher_notes_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:pdfx/pdfx.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TeacherNotesPage extends StatefulWidget {
  const TeacherNotesPage({super.key});

  @override
  _TeacherNotesPageState createState() => _TeacherNotesPageState();
}

class _TeacherNotesPageState extends State<TeacherNotesPage> {
  bool _isUploading = false;
  bool _isExtracting = false;

  // Get reference to the custom Firestore database
  final db = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: "cote",
  );

  Future<String> _extractTextFromPDF(Uint8List pdfData) async {
    try {
      setState(() {
        _isExtracting = true;
      });

      final doc = await PdfDocument.openData(pdfData);
      final List<Uint8List> images = [];
      String allText = '';

      // Convert PDF pages to images
      for (int i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        final rendered = await page.render(
          width: page.width,
          height: page.height,
          format: PdfPageImageFormat.jpeg,
        );
        if (rendered != null) {
          images.add(rendered.bytes);
        }
        await page.close();
      }
      await doc.close();

      // Extract text from images
      for (var img in images) {
        final text = await _extractTextFromImage(img);
        if (text.isNotEmpty) {
          allText += text + '\n\n';
        }
      }

      return allText;
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    } finally {
      setState(() {
        _isExtracting = false;
      });
    }
  }

  Future<String> _extractTextFromImage(Uint8List imageBytes) async {
    try {
      final client = await _getAuthClient();
      final api = vision.VisionApi(client);

      final encodedImage = base64Encode(imageBytes);

      final request = vision.AnnotateImageRequest(
        image: vision.Image(content: encodedImage),
        features: [vision.Feature(type: 'TEXT_DETECTION')],
      );

      final batch = vision.BatchAnnotateImagesRequest(requests: [request]);
      final response = await api.images.annotate(batch);

      if (response.responses != null &&
          response.responses!.isNotEmpty &&
          response.responses!.first.textAnnotations != null &&
          response.responses!.first.textAnnotations!.isNotEmpty) {
        return response.responses!.first.textAnnotations!.first.description ?? '';
      }
      return '';
    } catch (e) {
      print('Error in text extraction from image: $e');
      return '';
    }
  }

  Future<http.Client> _getAuthClient() async {
    try {
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      final credentials = ServiceAccountCredentials.fromJson(jsonMap);
      final scopes = ['https://www.googleapis.com/auth/cloud-vision'];
      return clientViaServiceAccount(credentials, scopes);
    } catch (e) {
      print('Authentication error: $e');
      throw Exception('Failed to authenticate with Google Cloud: $e');
    }
  }

  Future<void> _uploadPDF() async {
    final XTypeGroup typeGroup = XTypeGroup(label: 'pdf', extensions: ['pdf']);
    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        final String fileName = file.name;
        final Uint8List fileBytes = await file.readAsBytes();

        // Extract text from PDF
        final String extractedText = await _extractTextFromPDF(fileBytes);

        // Upload to Firebase Storage
        final ref = FirebaseStorage.instance.ref().child('notes/$fileName');
        await ref.putData(fileBytes);
        final url = await ref.getDownloadURL();

        // Store in Firestore with extracted text
        await db.collection('notes').add({
          'title': fileName,
          'url': url,
          'extractedText': extractedText,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } catch (e) {
        print("Error uploading file: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher - Upload Notes")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isExtracting)
              Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Extracting text from PDF..."),
                ],
              ),
            ElevatedButton(
              onPressed: (_isUploading || _isExtracting) ? null : _uploadPDF,
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Upload PDF'),
            ),
          ],
        ),
      ),
    );
  }
}