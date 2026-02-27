import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Added
import '../db/database_helper.dart'; // Added

class CreatePresentationScreen extends StatefulWidget {
  const CreatePresentationScreen({super.key});

  @override
  State<CreatePresentationScreen> createState() =>
      _CreatePresentationScreenState();
}

class _CreatePresentationScreenState extends State<CreatePresentationScreen> {
  final String apiBase =
      "https://your-corecslab-api.example.com/create_presentation.php";

  final TextEditingController _descriptionController = TextEditingController();
  final List<TextEditingController> _codeControllers = [
    TextEditingController(),
  ];
  final List<Criteria> _criteriaList = [
    Criteria(description: '', marks: 0, commentsAllowed: false),
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createPresentation() async {
    if (_descriptionController.text.isEmpty) {
      _showSnackBar("Please enter presentation description", Colors.red);
      return;
    }

    // Validate codes
    final codes = _codeControllers
        .map((c) => c.text.trim())
        .where((code) => code.isNotEmpty)
        .toList();
    if (codes.isEmpty) {
      _showSnackBar("Please add at least one presentation code", Colors.red);
      return;
    }

    // Validate criteria
    for (var criteria in _criteriaList) {
      if (criteria.description.isEmpty) {
        _showSnackBar("Please fill all criteria descriptions", Colors.red);
        return;
      }
      if (criteria.marks < 0) {
        _showSnackBar("Marks cannot be negative", Colors.red);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      // --- STEP 1: SAVE TO LOCAL DATABASE (For Admin Logic) ---
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String myEmail = prefs.getString('my_email') ?? "";

      // Insert into local SQLite so "My Presentations" works immediately
      int localId = await DatabaseHelper.instance.insertPresentation({
        'descriptions': _descriptionController.text.trim(), // Matches schema
        'creator_email': myEmail, // <--- CRITICAL: Saves your email as Admin
        'is_visible': 1,
        'are_results_visible': 0,
      });
      // ---------------------------------------------------------

      // --- STEP 2: SEND TO REMOTE SERVER (Existing Logic) ---
      final Map<String, dynamic> requestData = {
        'description': _descriptionController.text.trim(),
        'codes': codes,
        'criteria': _criteriaList
            .map(
              (c) => {
                'description': c.description,
                'marks': c.marks,
                'comments_allowed': c.commentsAllowed ? 'Yes' : 'No',
              },
            )
            .toList(),
        'creator_email': myEmail, // Ensure server also gets this if updated
      };

      final response = await http.post(
        Uri.parse('$apiBase/create_presentation.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success']) {
          _showSnackBar("Presentation created successfully!", Colors.green);
          _resetForm();
          // Optional: Navigate back immediately if desired
          // Navigator.pop(context, true);
        } else {
          _showSnackBar("Failed: ${result['message']}", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _descriptionController.clear();
    _codeControllers.clear();
    _codeControllers.add(TextEditingController());
    _criteriaList.clear();
    _criteriaList.add(
      Criteria(description: '', marks: 0, commentsAllowed: false),
    );
    setState(() {});
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPresentationInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF002147).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.add_chart_rounded,
                  size: 24,
                  color: const Color(0xFF002147),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Create New Presentation",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF002147),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Presentation Description",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
            ),
            child: TextField(
              controller: _descriptionController,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: const Color(0xFF002147),
              ),
              decoration: InputDecoration(
                hintText: "e.g., Final Year Defense, Mid-term Presentation",
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: const Color(0xFF6C757D),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Presentation Codes",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF002147),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _codeControllers.add(TextEditingController());
                  });
                },
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF002147),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Students will use these codes to join the presentation",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 16),
          ..._codeControllers.asMap().entries.map((entry) {
            int index = entry.key;
            TextEditingController controller = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _codeControllers.length - 1 ? 0 : 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: const Color(0xFF002147),
                        ),
                        decoration: InputDecoration(
                          hintText: "Enter 4-digit code (e.g., 1122)",
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: const Color(0xFF6C757D),
                          ),
                          prefixIcon: Icon(
                            Icons.lock_rounded,
                            color: const Color(0xFF002147),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_codeControllers.length > 1)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          controller.dispose();
                          _codeControllers.removeAt(index);
                        });
                      },
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: const Color(0xFFE74C3C),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCriteriaCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Evaluation Criteria",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF002147),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _criteriaList.add(
                      Criteria(
                        description: '',
                        marks: 0,
                        commentsAllowed: false,
                      ),
                    );
                  });
                },
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF002147),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Define how students will be evaluated",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: const Color(0xFF6C757D),
            ),
          ),
          const SizedBox(height: 16),
          ..._criteriaList.asMap().entries.map((entry) {
            int index = entry.key;
            Criteria criteria = entry.value;
            return Container(
              margin: EdgeInsets.only(
                bottom: index == _criteriaList.length - 1 ? 0 : 16,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF002147).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            "${index + 1}",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF002147),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE9ECEF),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                criteria.description = value;
                              });
                            },
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: const Color(0xFF002147),
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  "Criterion description (e.g., Content Knowledge)",
                              hintStyle: TextStyle(
                                fontFamily: 'Poppins',
                                color: const Color(0xFF6C757D),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ),
                      if (_criteriaList.length > 1)
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _criteriaList.removeAt(index);
                            });
                          },
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: const Color(0xFFE74C3C),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Maximum Marks",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: const Color(0xFF6C757D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE9ECEF),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  setState(() {
                                    criteria.marks = int.tryParse(value) ?? 0;
                                  });
                                },
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: const Color(0xFF002147),
                                ),
                                decoration: InputDecoration(
                                  hintText: "0-100",
                                  hintStyle: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: const Color(0xFF6C757D),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Feedback Type",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: const Color(0xFF6C757D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE9ECEF),
                                  width: 1,
                                ),
                              ),
                              child: SwitchListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                title: Text(
                                  criteria.commentsAllowed
                                      ? "Comments Only"
                                      : "Marks Only",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: const Color(0xFF002147),
                                  ),
                                ),
                                value: criteria.commentsAllowed,
                                onChanged: (value) {
                                  setState(() {
                                    criteria.commentsAllowed = value;
                                    if (value) criteria.marks = 0;
                                  });
                                },
                                activeColor: const Color(0xFF002147),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (criteria.commentsAllowed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: const Color(0xFFD4AF37),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "This criterion will accept only written feedback (no marks)",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: const Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Create Presentation",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002147),
        elevation: 2,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildPresentationInfoCard(),
            _buildCodesCard(),
            _buildCriteriaCard(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _createPresentation,
                  icon: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.add_task_rounded, size: 20),
                  label: Text(
                    _isSubmitting
                        ? "Creating Presentation..."
                        : "CREATE PRESENTATION",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002147),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class Criteria {
  String description;
  int marks;
  bool commentsAllowed;

  Criteria({
    required this.description,
    required this.marks,
    required this.commentsAllowed,
  });
}
