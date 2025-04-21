import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:pdfx/pdfx.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class ExtractTextPage extends StatefulWidget {
  final String url; // Firebase Storage URL to the PDF

  const ExtractTextPage({Key? key, required this.url}) : super(key: key);

  @override
  State<ExtractTextPage> createState() => _ExtractTextPageState();
}

class _ExtractTextPageState extends State<ExtractTextPage> {
  List<Map<String, dynamic>> generatedQuestions = []; // Questions for quiz
  List<int?> selectedAnswers = [];  // Store selected answers for each question
  bool isLoading = true;

  final String geminiApiKey = "AIzaSyAw1u_V1Kfb-p-aU68lbGEBkB_LNBQmao4";  // Replace with actual Gemini API Key

  @override
  void initState() {
    super.initState();
    _extractTextFromPDF(widget.url);
  }

  // Step 1: Extract text from the PDF
  Future<void> _extractTextFromPDF(String url) async {
    try {
      // Step 1: Download the PDF
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

      // Step 3: Send extracted images to Google Vision API to get text
      String allText = '';
      for (var img in images) {
        final text = await _extractTextFromImage(img);
        if (text.isNotEmpty) {
          allText += text + '\n\n';
        }
      }
      
      // Only generate MCQs once from all the combined text
      if (allText.isNotEmpty) {
        await _generateMCQs(allText);
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

  // Function to extract text from the image using Google Cloud Vision API
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

  // Function to authenticate the Vision API client
  Future<http.Client> _getAuthClient() async {
    try {
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;

      // Create credentials
      final credentials = ServiceAccountCredentials.fromJson(jsonMap);

      // Get the authenticated client
      final scopes = ['https://www.googleapis.com/auth/cloud-vision'];

      return clientViaServiceAccount(credentials, scopes);
    } catch (e) {
      print('Authentication error: $e');
      throw Exception('Failed to authenticate with Google Cloud: $e');
    }
  }

  // Step 4: Generate MCQs from the extracted text using Gemini API with Google AI SDK
  Future<void> _generateMCQs(String extractedText) async {
    try {
      print('Generating MCQs from extracted text: ${extractedText.substring(0, min(100, extractedText.length))}...');
      
      // Initialize the Gemini model using the Google AI SDK
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',  // Use the correct Gemini model name (replace with actual model name if different)
        apiKey: geminiApiKey,
      );
      
      final prompt = """Generate 5 multiple-choice questions (MCQs) with 4 options each based on the following text. 
      For each question, clearly indicate which option is the correct answer by marking it with [CORRECT].
      Format the output as follows:
      Q1: [Question text]
      A: [Option 1]
      B: [Option 2]
      C: [Option 3] [CORRECT]
      D: [Option 4]
      
      TEXT: $extractedText""";
      
      final content = [Content.text(prompt)];
      
      // Generate content
      final response = await model.generateContent(content);
      final generatedText = response.text;
      
      print('Generated text from Gemini: $generatedText');
      
      if (generatedText != null && generatedText.isNotEmpty) {
        // Process the generated text into structured MCQs
        List<Map<String, dynamic>> questions = _parseQuestions(generatedText);
        
        setState(() {
          generatedQuestions = questions;
          selectedAnswers = List.filled(generatedQuestions.length, null);
        });
      } else {
        print('Error: Empty response from Gemini');
        setState(() {
          generatedQuestions = [];
        });
      }
    } catch (e) {
      print('Error generating MCQs: $e');
      setState(() {
        generatedQuestions = [];
        isLoading = false;
      });
    }
  }

  // Helper method to parse the generated text into structured questions
  List<Map<String, dynamic>> _parseQuestions(String text) {
    List<Map<String, dynamic>> questions = [];
    
    try {
      // Split the text by question markers (Q1:, Q2:, etc.)
      final questionBlocks = text.split(RegExp(r'Q\d+:')).where((s) => s.trim().isNotEmpty).toList();
      
      for (var block in questionBlocks) {
        try {
          // Extract the question text
          final questionLines = block.trim().split('\n');
          final questionText = questionLines[0].trim();
          
          // Extract the options
          List<String> options = [];
          int correctAnswerIndex = -1;
          
          for (int i = 1; i < questionLines.length; i++) {
            if (questionLines[i].trim().isEmpty) continue;
            
            final optionMatch = RegExp(r'^([A-D]):\s*(.+)$').firstMatch(questionLines[i].trim());
            if (optionMatch != null) {
              final optionText = optionMatch.group(2)!.replaceAll('[CORRECT]', '').trim();
              options.add(optionText);
              
              if (questionLines[i].contains('[CORRECT]')) {
                correctAnswerIndex = options.length - 1;
              }
            }
          }
          
          // Only add complete questions with at least 2 options and a marked correct answer
          if (options.length >= 2 && correctAnswerIndex >= 0) {
            questions.add({
              'question': questionText,
              'options': options,
              'correctAnswer': correctAnswerIndex,
            });
          }
        } catch (e) {
          print('Error parsing question block: $e');
          // Skip this question if there was an error
        }
      }
      
      print('Successfully parsed ${questions.length} questions');
      return questions;
    } catch (e) {
      print('Error in question parsing: $e');
      return [];
    }
  }

  // Function to handle answer selection
  void _onOptionSelected(int questionIndex, int answerIndex) {
    setState(() {
      selectedAnswers[questionIndex] = answerIndex;
    });
  }

  // Function to submit the quiz and show results
  void _submitQuiz() {
    int score = 0;

    for (int i = 0; i < generatedQuestions.length; i++) {
      if (selectedAnswers[i] == generatedQuestions[i]['correctAnswer']) {
        score++;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(score: score, total: generatedQuestions.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : generatedQuestions.isEmpty
              ? const Center(child: Text("No questions found. Please try again."))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Answer the following questions:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          itemCount: generatedQuestions.length,
                          itemBuilder: (context, index) {
                            final question = generatedQuestions[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(question['question'], style: TextStyle(fontSize: 16)),
                                    const SizedBox(height: 10),
                                    ...List.generate(
                                      question['options'].length,
                                      (optionIndex) => ListTile(
                                        title: Text(question['options'][optionIndex]),
                                        leading: Radio<int>(
                                          value: optionIndex,
                                          groupValue: selectedAnswers[index],
                                          onChanged: (value) {
                                            _onOptionSelected(index, value!);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _submitQuiz,
                        child: const Text("Submit Quiz"),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// Result screen to display the quiz results
class ResultScreen extends StatelessWidget {
  final int score;
  final int total;

  const ResultScreen({Key? key, required this.score, required this.total}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quiz Result")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Your Score: $score/$total", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, ModalRoute.withName('/student_home'));
              },
              child: const Text("Go Back to Dashboard"),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function for min
int min(int a, int b) => a < b ? a : b;
