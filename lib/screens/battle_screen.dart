import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:googleapis_auth/auth_io.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'result_screen.dart';


class BattleScreen extends StatefulWidget {
  final String noteId;
  final String noteUrl;
  final String teamCode;
  final DateTime startTime;

  const BattleScreen({
    super.key,
    required this.noteId,
    required this.noteUrl,
    required this.teamCode,
    required this.startTime,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  List<Map<String, dynamic>> questions = [];
  Map<int, int?> selectedAnswers = {};
  int remainingSeconds = 60;
  Timer? timer;
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _generateQuizFromNote();
  }

  void _startTimer() {
    if (!mounted) return;
    
    final now = DateTime.now();
    int elapsed = now.difference(widget.startTime).inSeconds;
    remainingSeconds = max(0, 60 - elapsed);

    if (remainingSeconds <= 0) {
      _submit();
      return;
    }

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      
      setState(() => remainingSeconds--);
      if (remainingSeconds <= 0) {
        t.cancel();
        _submit();
      }
    });
  }

  Future<void> _generateQuizFromNote() async {
    try {
      // Get PDF data from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(widget.noteUrl);
      final pdfData = await ref.getData();
      
      if (pdfData == null || pdfData.isEmpty) {
        throw Exception("Failed to download PDF data");
      }

      // Process PDF
      final doc = await PdfDocument.openData(pdfData);
      List<Uint8List> images = [];

      // Extract images from all pages
      for (int i = 1; i <= doc.pagesCount; i++) {
        try {
          final page = await doc.getPage(i);
          final rendered = await page.render(
            width: page.width,
            height: page.height,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
          
          if (rendered != null) {
            images.add(rendered.bytes);
          }
          await page.close();
        } catch (e) {
          print("Error rendering page $i: $e");
          // Continue with other pages even if one fails
        }
      }
      await doc.close();

      if (images.isEmpty) {
        throw Exception("Failed to extract images from PDF");
      }

      // Process each image with OCR
      String fullText = "";
      for (var image in images) {
        try {
          final extracted = await _extractTextFromImage(image);
          fullText += "$extracted\n";
        } catch (e) {
          print("Error extracting text from image: $e");
          // Continue with other images even if one fails
        }
      }

      if (fullText.trim().isEmpty) {
        throw Exception("No text was extracted from the PDF");
      }

      // Generate MCQs from the extracted text
      await _generateMCQs(fullText);

      if (!mounted) return;
      
      setState(() => isLoading = false);
      _startTimer(); // Start timer after questions are ready
    } catch (e) {
      print("Error generating quiz: $e");
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
        errorMessage = "Failed to generate quiz: ${e.toString()}";
      });
    }
  }

  Future<String> _extractTextFromImage(Uint8List bytes) async {
    try {
      final authClient = await _getAuthClient();
      final api = vision.VisionApi(authClient);
      final encoded = base64Encode(bytes);

      final request = vision.AnnotateImageRequest(
        image: vision.Image(content: encoded),
        features: [vision.Feature(type: 'TEXT_DETECTION', maxResults: 1)],
      );

      final batch = vision.BatchAnnotateImagesRequest(requests: [request]);
      final res = await api.images.annotate(batch);

      if (res.responses != null &&
          res.responses!.isNotEmpty &&
          res.responses!.first.textAnnotations != null &&
          res.responses!.first.textAnnotations!.isNotEmpty) {
        return res.responses!.first.textAnnotations!.first.description ?? '';
      }
      return '';
    } catch (e) {
      print("Vision API error: $e");
      return '';
    }
  }

  Future<AutoRefreshingAuthClient> _getAuthClient() async {
    try {
      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      final credentials = ServiceAccountCredentials.fromJson(jsonData);
      final scopes = ['https://www.googleapis.com/auth/cloud-vision'];
      return await clientViaServiceAccount(credentials, scopes);
    } catch (e) {
      print("Error getting auth client: $e");
      rethrow;
    }
  }

  Future<void> _generateMCQs(String text) async {
    try {
      // Replace with your actual API key from a secure source
      const apiKey = "AIzaSyAw1u_V1Kfb-p-aU68lbGEBkB_LNBQmao4";
          
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      // Truncate text if too long (Gemini has input limits)
      final truncatedText = text.length > 30000 ? text.substring(0, 30000) : text;

      final prompt = """
Generate 5 multiple-choice questions from this text. Format:
Q1: [Question]
A: [Option 1]
B: [Option 2]
C: [Option 3] [CORRECT]
D: [Option 4]

$truncatedText
""";

      final res = await model.generateContent([Content.text(prompt)]);
      final raw = res.text ?? "";
      
      if (raw.isEmpty) {
        throw Exception("Generated no content from Gemini");
      }
      
      final parsed = _parseMCQs(raw);
      
      if (parsed.isEmpty) {
        throw Exception("Failed to parse questions from Gemini response");
      }
      
      if (!mounted) return;
      
      setState(() {
        questions = parsed;
        for (int i = 0; i < questions.length; i++) {
          selectedAnswers[i] = null;
        }
      });
    } catch (e) {
      print("Error generating MCQs: $e");
      rethrow;
    }
  }

  List<Map<String, dynamic>> _parseMCQs(String raw) {
    final List<Map<String, dynamic>> output = [];
    
    // Fixed the RegExp split issue - Using String methods instead
    final pattern = RegExp(r'Q\d+:|Question \d+:');
    final matches = pattern.allMatches(raw).toList();
    
    if (matches.isEmpty) {
      // Try to parse the entire text as one question if no Q pattern is found
      return _tryParseAsOneQuestion(raw);
    }
    
    // Process each question block
    for (int i = 0; i < matches.length; i++) {
      final startIndex = matches[i].start;
      final endIndex = i < matches.length - 1 ? matches[i + 1].start : raw.length;
      final block = raw.substring(startIndex, endIndex).trim();
      
      try {
        final questionStartIndex = block.indexOf(':') + 1;
        if (questionStartIndex <= 0) continue;
        
        final lines = block.substring(questionStartIndex).trim().split('\n');
        if (lines.isEmpty) continue;
        
        final question = lines[0].trim();
        List<String> options = [];
        int correct = -1;

        // Find option lines and identify the correct one
        for (int j = 1; j < lines.length; j++) {
          final line = lines[j].trim();
          if (line.isEmpty) continue;
          
          final optionMatch = RegExp(r'^([A-D])[\s:\.\)]+(.+?)(\s*\[CORRECT\])?$').firstMatch(line);
          
          if (optionMatch != null) {
            final text = optionMatch.group(2)!.trim();
            options.add(text);
            if (line.contains('[CORRECT]')) {
              correct = options.length - 1;
            }
          }
        }

        // If correct answer wasn't marked with [CORRECT], try inferring from ✓ or * or similar markers
        if (correct == -1 && options.length == 4) {
          for (int j = 0; j < options.length; j++) {
            if (options[j].contains('✓') || options[j].contains('*') || options[j].contains('(correct)')) {
              // Clean the option text
              options[j] = options[j].replaceAll('✓', '').replaceAll('*', '').replaceAll('(correct)', '').trim();
              correct = j;
              break;
            }
          }
        }
        
        // Default to first option if no correct answer is indicated
        if (correct == -1 && options.length == 4) {
          correct = 0;
        }

        if (options.length == 4 && question.isNotEmpty) {
          output.add({
            'question': question,
            'options': options,
            'correctAnswer': correct,
          });
        }
      } catch (e) {
        print("Error parsing question block: $e");
        continue;
      }
    }

    return output;
  }
  
  List<Map<String, dynamic>> _tryParseAsOneQuestion(String raw) {
    // Try to parse text without the Q prefix
    final lines = raw.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    
    final question = lines[0].trim();
    List<String> options = [];
    int correct = -1;
    
    // Find options
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      final optionMatch = RegExp(r'^([A-D])[\s:\.\)]+(.+?)(\s*\[CORRECT\])?$').firstMatch(line);
      
      if (optionMatch != null) {
        final text = optionMatch.group(2)!.trim();
        options.add(text);
        if (line.contains('[CORRECT]')) {
          correct = options.length - 1;
        }
      }
    }
    
    // Set default correct answer if needed
    if (correct == -1 && options.length == 4) {
      correct = 0;
    }
    
    if (options.length == 4 && question.isNotEmpty) {
      return [{
        'question': question,
        'options': options,
        'correctAnswer': correct,
      }];
    }
    
    return [];
  }

  void _submit() {
    timer?.cancel();

    final results = questions.asMap().entries.map((entry) {
      final index = entry.key;
      final q = entry.value;
      return {
        'question': q['question'],
        'options': q['options'],
        'correctAnswer': q['correctAnswer'],
        'selectedAnswer': selectedAnswers[index],
      };
    }).toList();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: results),
        ),
      );
    }
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Battle"),
        actions: [
          if (!isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "$remainingSeconds s",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = '';
                            });
                            _generateQuizFromNote();
                          },
                          child: const Text("Try Again"),
                        ),
                      ],
                    ),
                  ),
                )
              : questions.isEmpty
                  ? const Center(child: Text("No questions could be generated"))
                  : ListView.builder(
                      itemCount: questions.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Q${index + 1}: ${q['question']}", 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  )
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(q['options'].length, (i) {
                                  final letter = String.fromCharCode(65 + i); // A, B, C, D
                                  return RadioListTile<int>(
                                    value: i,
                                    groupValue: selectedAnswers[index],
                                    title: Text("$letter. ${q['options'][i]}"),
                                    dense: true,
                                    onChanged: (val) {
                                      setState(() {
                                        selectedAnswers[index] = val;
                                      });
                                    },
                                  );
                                })
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: !isLoading && errorMessage.isEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    "Submit Now",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}