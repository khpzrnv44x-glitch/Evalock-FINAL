import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key});

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  final TextEditingController _topicController = TextEditingController();
  String _result = "";
  bool _isLoading = false;

  // YOUR API KEY (Verified working for 2.5 Flash)
  final String _apiKey = "YOUR_GEMINI_API_KEY";

  Future<void> _generateContent(String promptType) async {
    if (_topicController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a topic first")),
      );
      return;
    }

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    String prompt = promptType == "create"
        ? "Create a 10 TO 12 slides presentation outline and key points for: ${_topicController.text}"
        : "Generate 10 viva/preparation questions for the topic: ${_topicController.text}";

    try {
      // FIX: Using 'gemini-2.5-flash' on 'v1beta'
      // This matches the exact configuration from your Postman test.
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
              ],
            },
          ],
          "generationConfig": {"temperature": 0.7, "maxOutputTokens": 2000},
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String text =
            data['candidates']?[0]['content']?['parts']?[0]['text'] ??
            "No text generated.";
        setState(() => _result = text);
      } else {
        // This will print the specific error if it fails again
        var errorData = jsonDecode(response.body);
        String errorMessage = errorData['error']['message'] ?? response.body;
        setState(
          () => _result = "Error (${response.statusCode}): $errorMessage",
        );
      }
    } catch (e) {
      setState(() => _result = "Connection Error: $e");
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "AI Preparation Studio",
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        backgroundColor: const Color(0xFF002147),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: "Enter Presentation Topic ",
                labelStyle: TextStyle(fontFamily: 'Poppins'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic, color: Color(0xFF002147)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _generateContent("create"),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text(
                      "Generate Slides",
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _generateContent("prep"),
                    icon: const Icon(Icons.question_answer),
                    label: const Text(
                      "Get Questions",
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002147),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF002147),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          _result.isEmpty
                              ? "AI Output will appear here..."
                              : _result,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
