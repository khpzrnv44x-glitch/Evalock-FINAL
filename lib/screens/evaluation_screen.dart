import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../db/database_helper.dart';

class EvaluationScreen extends StatefulWidget {
  final String presentationId;
  final String presentationName;
  const EvaluationScreen({
    super.key,
    required this.presentationId,
    required this.presentationName,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final String apiBase = "https://your-corecslab-api.example.com";

  List<User> students = [];
  List<Map<String, dynamic>> criteriaList = [];
  User? selectedStudent;
  bool isLoading = true;
  bool isUploading = false;
  String myEmail = "";

  final Map<String, double> _sliderValues = {};
  final Map<String, TextEditingController> _commentControllers = {};

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Normalize myEmail for consistent comparison
    myEmail = (prefs.getString('my_email') ?? "").trim().toLowerCase();

    // 1. Get Criteria
    criteriaList = await DatabaseHelper.instance.getCriteriaForPresentation(
      widget.presentationId,
    );

    // 2. Initialize Controllers
    for (var c in criteriaList) {
      String id = c['id'].toString();
      _sliderValues[id] = 0.0;
      if (c['comments_allowed'] == 'Yes') {
        _commentControllers[id] = TextEditingController();
      }
    }

    // 3. Get Students and Filter Myself Out
    final localStudents = await DatabaseHelper.instance.getLocalStudents();
    students = localStudents.where((u) {
      // Normalize user email for comparison
      String uEmail = u.email.trim().toLowerCase();
      // Exclude if email matches mine OR if email is empty (invalid user)
      return uEmail != myEmail && uEmail.isNotEmpty;
    }).toList();

    setState(() => isLoading = false);
  }

  Future<void> _onStudentSelected(User student) async {
    setState(() => selectedStudent = student);

    // Reset Form First
    for (var key in _sliderValues.keys) _sliderValues[key] = 0.0;
    for (var key in _commentControllers.keys) _commentControllers[key]?.clear();

    // Load from DB if exists
    List<Map<String, dynamic>> existingData = await DatabaseHelper.instance
        .getLocalEvaluation(student.email, myEmail, widget.presentationId);

    setState(() {
      for (var row in existingData) {
        String catId = row['category_id'].toString();
        if (_sliderValues.containsKey(catId)) {
          _sliderValues[catId] = (row['obtained_marks'] as num).toDouble();
        }
        if (_commentControllers.containsKey(catId)) {
          _commentControllers[catId]?.text = row['feedback_text'] ?? "";
        }
      }
    });
  }

  Future<void> _saveLocally() async {
    if (selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Please select a student first",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    List<Map<String, dynamic>> rows = [];
    for (var c in criteriaList) {
      String catId = c['id'].toString();
      rows.add({
        'evaluated_student': selectedStudent!.email,
        'evaluated_by': myEmail,
        'category_id': int.parse(catId),
        'obtained_marks': c['comments_allowed'] == 'Yes'
            ? 0.0
            : (_sliderValues[catId] ?? 0.0),
        'feedback_text': c['comments_allowed'] == 'Yes'
            ? _commentControllers[catId]?.text
            : "",
      });
    }

    await DatabaseHelper.instance.saveEvaluationRows(rows);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Evaluation saved locally",
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF002147),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _uploadToServer() async {
    setState(() => isUploading = true);
    try {
      final pending = await DatabaseHelper.instance.getPendingEvaluations();
      if (pending.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No evaluations to upload",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF6C757D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        setState(() => isUploading = false);
        return;
      }

      // Group by student for efficient API calls
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var row in pending) {
        String key = "${row['evaluated_student']}_${row['evaluated_by']}";
        if (!grouped.containsKey(key)) grouped[key] = [];
        grouped[key]!.add(row);
      }

      for (var key in grouped.keys) {
        var rows = grouped[key]!;
        Map<String, dynamic> body = {
          "evaluated_student": rows[0]['evaluated_student'],
          "evaluated_by": rows[0]['evaluated_by'],
          "details": rows
              .map(
                (r) => {
                  "category_id": r['category_id'],
                  "obtained_marks": r['obtained_marks'],
                  "feedback_text": r['feedback_text'],
                },
              )
              .toList(),
        };

        await http.post(
          Uri.parse('$apiBase/insert_evaluation.php'),
          body: jsonEncode(body),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await DatabaseHelper.instance.markAsSynced();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Evaluations uploaded successfully!",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFF27AE60),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Upload failed: $e",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: const Color(0xFFE74C3C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    setState(() => isUploading = false);
  }

  // --- FIXED: Uses a separate Widget class to maintain state during keyboard shifts ---
  void _showStudentSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      // Use the separate widget here
      builder: (context) => StudentSearchSheet(
        students: students,
        onSelect: (student) {
          Navigator.pop(context);
          _onStudentSelected(student);
        },
      ),
    );
  }

  Widget _buildCriteriaItem(Map<String, dynamic> c) {
    String id = c['id'].toString();
    double max = (c['marks'] as num).toDouble();
    bool isComment = c['comments_allowed'] == 'Yes';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isComment
                          ? const Color(0xFFD4AF37).withOpacity(0.1)
                          : const Color(0xFF002147).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      isComment ? Icons.comment_rounded : Icons.grading_rounded,
                      size: 18,
                      color: isComment
                          ? const Color(0xFFD4AF37)
                          : const Color(0xFF002147),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      c['description'],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF002147),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (isComment)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE9ECEF),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _commentControllers[id],
                    maxLines: 3,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: const Color(0xFF002147),
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter your feedback here...",
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: const Color(0xFF6C757D),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Marks Allocation",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: const Color(0xFF6C757D),
                          ),
                        ),
                        Text(
                          "${_sliderValues[id]?.toStringAsFixed(1)} / $max",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF002147),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                          disabledThumbRadius: 10,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: 20,
                        ),
                        activeTrackColor: const Color(0xFF002147),
                        inactiveTrackColor: const Color(
                          0xFF002147,
                        ).withOpacity(0.2),
                        thumbColor: const Color(0xFF002147),
                        overlayColor: const Color(0xFF002147).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _sliderValues[id] ?? 0.0,
                        min: 0,
                        max: max,
                        divisions: (max * 2).toInt(),
                        onChanged: (v) => setState(() => _sliderValues[id] = v),
                        label: _sliderValues[id]?.toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "0",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: const Color(0xFF6C757D),
                          ),
                        ),
                        Text(
                          "Max: $max",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: const Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.presentationName,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      body: isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Student Selector Card
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    elevation: 0,
                    child: InkWell(
                      onTap: _showStudentSearchDialog,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: selectedStudent == null
                                    ? const Color(0xFF6C757D).withOpacity(0.1)
                                    : const Color(0xFF27AE60).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Icon(
                                selectedStudent == null
                                    ? Icons.person_add_rounded
                                    : Icons.person,
                                size: 28,
                                color: selectedStudent == null
                                    ? const Color(0xFF6C757D)
                                    : const Color(0xFF27AE60),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedStudent?.name ?? "Select Student",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: selectedStudent == null
                                          ? const Color(0xFF6C757D)
                                          : const Color(0xFF002147),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedStudent?.email ??
                                        "Tap to choose student for evaluation",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: const Color(0xFF6C757D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 20,
                              color: const Color(0xFF002147),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Criteria List
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (selectedStudent != null) ...[
                          const SizedBox(height: 8),
                          ...criteriaList.map(_buildCriteriaItem).toList(),
                          const SizedBox(height: 24),

                          // Action Buttons
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _saveLocally,
                                    icon: Icon(Icons.save_rounded, size: 20),
                                    label: Text(
                                      "SAVE EVALUATION LOCALLY",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF002147),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: isUploading
                                        ? null
                                        : _uploadToServer,
                                    icon: isUploading
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            Icons.cloud_upload_rounded,
                                            size: 20,
                                          ),
                                    label: Text(
                                      isUploading
                                          ? "UPLOADING TO SERVER..."
                                          : "UPLOAD TO SERVER",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF27AE60),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          _buildNoStudentSelected(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: const Color(0xFF002147),
                  backgroundColor: const Color(0xFF002147).withOpacity(0.1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Loading Evaluation Form...",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF002147),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudentSelected() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.assignment_ind_rounded,
              size: 60,
              color: const Color(0xFF002147).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Select a Student",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Please select a student to evaluate from the card above",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: const Color(0xFF6C757D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showStudentSearchDialog,
              icon: Icon(Icons.search_rounded, size: 20),
              label: Text(
                "BROWSE STUDENTS",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002147),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW CLASS: Handles Search + Keyboard State Correctly ---
class StudentSearchSheet extends StatefulWidget {
  final List<User> students;
  final Function(User) onSelect;

  const StudentSearchSheet({
    Key? key,
    required this.students,
    required this.onSelect,
  }) : super(key: key);

  @override
  State<StudentSearchSheet> createState() => _StudentSearchSheetState();
}

class _StudentSearchSheetState extends State<StudentSearchSheet> {
  late List<User> filteredList;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredList = List.from(widget.students);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredList = List.from(widget.students);
      } else {
        filteredList = widget.students
            .where((u) => u.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF002147),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Student",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true, // Focus automatically
                decoration: InputDecoration(
                  hintText: "Search by name...",
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: const Color(0xFF6C757D),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: const Color(0xFF002147),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: const Color(0xFF002147),
                ),
                onChanged: _filterList,
              ),
            ),
          ),

          // Students List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 60,
                          color: const Color(0xFF6C757D).withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No students found",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: const Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFE9ECEF)),
                    itemBuilder: (context, index) {
                      final user = filteredList[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelect(user),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF002147,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 24,
                                    color: const Color(0xFF002147),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF002147),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        user.email,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: const Color(0xFF6C757D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: const Color(
                                    0xFF002147,
                                  ).withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
