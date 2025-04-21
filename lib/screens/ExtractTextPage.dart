import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:pdfx/pdfx.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

class ExtractTextPage extends StatefulWidget {
  final String url; // Firebase Storage URL to the PDF
  
  const ExtractTextPage({Key? key, required this.url}) : super(key: key);
  
  @override
  State<ExtractTextPage> createState() => _ExtractTextPageState();
}

class _ExtractTextPageState extends State<ExtractTextPage> {
  List<String> extractedText = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _extractTextFromPDF(widget.url);
  }
  
  Future<void> _extractTextFromPDF(String url) async {
    try {
      // Step 1: Download PDF
      final pdfData = await FirebaseStorage.instance.refFromURL(url).getData();
      final doc = await PdfDocument.openData(pdfData!);
      
      final List<Uint8List> images = [];
      
      // Step 2: Convert PDF pages to images
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
      
      // Step 3: Extract text from each image
      for (var img in images) {
        final text = await _extractTextFromImage(img);
        if (text.isNotEmpty) {
          setState(() {
            extractedText.add(text);
          });
        }
      }
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error during text extraction: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Future<String> _extractTextFromImage(Uint8List imageBytes) async {
    try {
      final client = await _getAuthClient();
      final api = vision.VisionApi(client);
      
      // The Vision API expects base64-encoded images
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
      // Load service account from assets
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      
      // Create credentials
      final credentials = ServiceAccountCredentials.fromJson(jsonMap);
      
      // Get access credentials
      final scopes = ['https://www.googleapis.com/auth/cloud-vision'];
      
      // Get the authenticated client
      return clientViaServiceAccount(credentials, scopes);
    } catch (e) {
      print('Authentication error: $e');
      throw Exception('Failed to authenticate with Google Cloud: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extracted Text')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : extractedText.isEmpty
              ? const Center(child: Text("No text was found in this document."))
              : ListView.builder(
                  itemCount: extractedText.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          extractedText[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}