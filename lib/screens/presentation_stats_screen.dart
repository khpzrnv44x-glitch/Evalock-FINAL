import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';
import '../db/database_helper.dart';

class PresentationStatsScreen extends StatefulWidget {
  final String presentationId;
  final String presentationName;
  final bool isMyEvaluation;
  final bool areResultsReleased;

  const PresentationStatsScreen({
    super.key,
    required this.presentationId,
    required this.presentationName,
    this.isMyEvaluation = false,
    this.areResultsReleased = true,
  });

  @override
  State<PresentationStatsScreen> createState() =>
      _PresentationStatsScreenState();
}

class _PresentationStatsScreenState extends State<PresentationStatsScreen> {
  // --- VARIABLES ---
  List<User> students = [];
  User? selectedStudent;
  bool isLoading = true;

  double percentage = 0.0;
  String performanceText = "Select Student";
  Color bubbleColor = const Color(0xFF6C757D);
  List<Map<String, dynamic>> commentsList = [];

  // --- ONLINE AI VARIABLES ---
  final String _apiKey = "YOUR_GEMINI_API_KEY";
  String aiAnalysisResult = "Select a student to view AI analysis.";
  bool isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (widget.isMyEvaluation && !widget.areResultsReleased) {
      setState(() => isLoading = false);
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String myId = prefs.getString('my_id') ?? "";
    String myEmail = prefs.getString('my_email') ?? "";
    String myName = prefs.getString('my_name') ?? "Unknown";
    String myRollNo = prefs.getString('my_roll_no') ?? "";

    if (widget.isMyEvaluation) {
      User me = User(id: myId, name: myName, email: myEmail, rollNo: myRollNo);
      students = [me];
      _calculateStats(me);
    } else {
      final localStudents = await DatabaseHelper.instance.getLocalStudents();
      students = localStudents.where((u) => u.email != myEmail).toList();
    }
    setState(() => isLoading = false);
  }

  Future<void> _calculateStats(User student) async {
    setState(() {
      selectedStudent = student;
      aiAnalysisResult = "Loading AI analysis...";
      isAiLoading = true;
    });

    List<Map<String, dynamic>> allStats = await DatabaseHelper.instance
        .getTeacherQueryB(widget.presentationId);

    var myStats = allStats.firstWhere((s) {
      String dbValue = s['evaluated_student'].toString().toLowerCase().trim();
      String searchEmail = student.email.toLowerCase().trim();
      String searchName = student.name.toLowerCase().trim();

      if (searchEmail.isNotEmpty && dbValue == searchEmail) return true;
      if (searchName.isNotEmpty && dbValue == searchName) return true;

      return false;
    }, orElse: () => {});

    if (myStats.isNotEmpty) {
      String actualDbKey = myStats['evaluated_student'];

      var comments = await DatabaseHelper.instance.getStudentComments(
        widget.presentationId,
        actualDbKey,
      );

      double pct = (myStats['percentage'] as num).toDouble();

      setState(() {
        percentage = pct;
        commentsList = comments;

        if (pct >= 80) {
          bubbleColor = const Color(0xFF27AE60);
          performanceText = "Excellent";
        } else if (pct >= 60) {
          bubbleColor = const Color(0xFF3498DB);
          performanceText = "Good";
        } else if (pct >= 40) {
          bubbleColor = const Color(0xFFF39C12);
          performanceText = "Average";
        } else {
          bubbleColor = const Color(0xFFE74C3C);
          performanceText = "Needs Improvement";
        }
      });

      _generateOnlineAIAnalysis();
    } else {
      setState(() {
        percentage = 0.0;
        commentsList = [];
        performanceText = "Not Evaluated";
        bubbleColor = const Color(0xFF6C757D);
        aiAnalysisResult = "Insufficient data for AI analysis.";
        isAiLoading = false;
      });
    }
  }

  // --- FINAL AI LOGIC: HIGH TOKEN LIMIT (1500) BUT SHORT CONTENT (50 Words) ---
  Future<void> _generateOnlineAIAnalysis() async {
    if (percentage == 0 && commentsList.isEmpty) {
      setState(() {
        isAiLoading = false;
        aiAnalysisResult = "No evaluation data available to analyze.";
      });
      return;
    }

    String prompt;

    if (commentsList.isEmpty) {
      // SCENARIO 1: NO COMMENTS (Analyze Score Only)
      prompt =
          """
        Role: Academic Evaluator.
        Task: Analyze the student based ONLY on their score ($percentage%).
        
        Instructions:
        1. If Score < 50%: Warn them they are at risk and must improve basics.
        2. If Score 50-79%: Acknowledge the pass but suggest deeper preparation.
        3. If Score > 80%: Congratulate them.
        4. YOU MUST END WITH: "No written feedback was provided."
        5. Keep total length under 50 words.
      """;
    } else {
      // SCENARIO 2: COMMENTS EXIST (Summarize ALL advice)
      String commentText = commentsList
          .map((c) => "${c['feedback_text']}")
          .join(". ");
      prompt =
          """
        Role: Academic Evaluator.
        Task: Create a single summary paragraph of ALL the following advice.
        
        Feedback to summarize: "$commentText"
        Score: $percentage%
        
        Instructions:
        1. Combine ALL pieces of advice (e.g. if one says 'database' and another says 'voice', mention BOTH).
        2. Speak directly to the student ("You need to...").
        3. If feedback is generic ("good", "ok"), use the score to give better advice.
        4. STRICT LIMIT: Maximum 50 words.
        5. Do not cut off the sentence.
      """;
    }

    try {
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
          "generationConfig": {
            "temperature": 0.5,
            // HIGH LIMIT to prevent cut-off, but Prompt enforces brevity.
            "maxOutputTokens": 1500,
          },
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String text =
            data['candidates']?[0]['content']?['parts']?[0]['text'] ??
            "AI could not generate an analysis.";
        setState(() {
          aiAnalysisResult = text.trim();
        });
      } else if (response.statusCode == 429) {
        setState(() {
          aiAnalysisResult =
              "⚠️ Too many requests. Please wait 1 minute before trying again.";
        });
      } else {
        setState(() {
          aiAnalysisResult = "AI Service Error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        aiAnalysisResult = "Connection Error: Check internet.";
      });
    } finally {
      setState(() {
        isAiLoading = false;
      });
    }
  }

  Future<void> _generatePdf() async {
    if (selectedStudent == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "EVALUATION REPORT",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Student Name: ${selectedStudent!.name}",
                style: const pw.TextStyle(fontSize: 18),
              ),
              pw.Text("Presentation: ${widget.presentationName}"),
              pw.Text("Date: ${DateTime.now().toString().split(' ')[0]}"),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Score: ${percentage.toStringAsFixed(1)}%",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Performance: $performanceText",
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                "AI Analysis",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                aiAnalysisResult,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Feedback & Comments",
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                },
                headers: ['Evaluator', 'Feedback'],
                data: commentsList.isEmpty
                    ? [
                        ['-', 'No written feedback provided'],
                      ]
                    : commentsList
                          .map(
                            (e) => [
                              e['evaluated_by'].toString(),
                              e['feedback_text'].toString(),
                            ],
                          )
                          .toList(),
              ),
              pw.Spacer(),
              pw.Text(
                "Powered by Evalock - Secure Evaluation System",
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "${selectedStudent!.name}_Report.pdf",
    );
  }

  String _getPerformanceLabel(double pct) {
    if (pct >= 85) return "Distinction";
    if (pct >= 70) return "Merit";
    if (pct >= 55) return "Pass";
    if (pct >= 40) return "Marginal";
    return "At Risk";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.isMyEvaluation
              ? "My Performance Dashboard"
              : "Presentation Analytics",
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
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
        actions: [
          if (percentage > 0 || commentsList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: "Download PDF Report",
              onPressed: _generatePdf,
            ),
        ],
      ),
      body: (widget.isMyEvaluation && !widget.areResultsReleased)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 80,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Results Not Released",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002147),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "The presenter has not published the results yet.\nPlease check back later.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.grey),
                  ),
                ],
              ),
            )
          : isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                // Presentation Header
                Container(
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
                            child: const Icon(
                              Icons.analytics_rounded,
                              size: 24,
                              color: Color(0xFF002147),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.presentationName,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF002147),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isMyEvaluation
                              ? const Color(0xFF3498DB).withOpacity(0.1)
                              : const Color(0xFFD4AF37).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.isMyEvaluation
                                ? const Color(0xFF3498DB).withOpacity(0.3)
                                : const Color(0xFFD4AF37).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.isMyEvaluation
                              ? "Student View"
                              : "Analyst View",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: widget.isMyEvaluation
                                ? const Color(0xFF3498DB)
                                : const Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!widget.isMyEvaluation)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButton<User>(
                          isExpanded: true,
                          value: selectedStudent,
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Color(0xFF002147),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: Color(0xFF002147),
                          ),
                          hint: const Text(
                            "Select student to analyze",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFF6C757D),
                            ),
                          ),
                          items: students.map((student) {
                            return DropdownMenuItem<User>(
                              value: student,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student.name,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF002147),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      student.email,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        color: Color(0xFF6C757D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _calculateStats(val);
                          },
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (selectedStudent != null) ...[
                          // Student Info Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
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
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        bubbleColor.withOpacity(0.2),
                                        bubbleColor.withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 32,
                                    color: bubbleColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedStudent!.name,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF002147),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedStudent!.email,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Color(0xFF6C757D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Performance Score Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE9ECEF),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "Performance Score",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Color(0xFF6C757D),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 180,
                                      height: 180,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: bubbleColor.withOpacity(0.3),
                                          width: 8,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 160,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: bubbleColor.withOpacity(0.5),
                                          width: 6,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "${percentage.toStringAsFixed(1)}%",
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 42,
                                            fontWeight: FontWeight.w700,
                                            color: bubbleColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bubbleColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            performanceText,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: bubbleColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _getPerformanceLabel(percentage),
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 12,
                                            color: Color(0xFF6C757D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildPerformanceIndicator(
                                      0,
                                      39,
                                      "At Risk",
                                      const Color(0xFFE74C3C),
                                    ),
                                    _buildPerformanceIndicator(
                                      40,
                                      54,
                                      "Marginal",
                                      const Color(0xFFF39C12),
                                    ),
                                    _buildPerformanceIndicator(
                                      55,
                                      69,
                                      "Pass",
                                      const Color(0xFF3498DB),
                                    ),
                                    _buildPerformanceIndicator(
                                      70,
                                      84,
                                      "Merit",
                                      const Color(0xFF27AE60),
                                    ),
                                    _buildPerformanceIndicator(
                                      85,
                                      100,
                                      "Distinction",
                                      const Color(0xFF2ECC71),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // AI Analysis Card (ONLINE)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF002147,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.psychology_rounded,
                                        size: 20,
                                        color: Color(0xFF002147),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "AI Performance Analysis",
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF002147),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF002147,
                                    ).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF002147,
                                      ).withOpacity(0.1),
                                    ),
                                  ),
                                  child: isAiLoading
                                      ? const Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF002147),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          aiAnalysisResult,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Color(0xFF002147),
                                            height: 1.5,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Feedback Comments Section
                          if (commentsList.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFD4AF37,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.feedback_rounded,
                                          size: 20,
                                          color: Color(0xFFD4AF37),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        "Feedback Comments",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF002147),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...commentsList.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    Map<String, dynamic> comment = entry.value;
                                    return Container(
                                      margin: EdgeInsets.only(
                                        bottom: index == commentsList.length - 1
                                            ? 0
                                            : 12,
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE9ECEF),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF002147,
                                                  ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  size: 16,
                                                  color: Color(0xFF002147),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  comment['evaluated_by'] ??
                                                      "Anonymous",
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF002147),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            comment['feedback_text'] ?? "",
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: Color(0xFF495057),
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ] else if (percentage > 0) ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    size: 48,
                                    color: const Color(
                                      0xFF6C757D,
                                    ).withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No feedback comments available",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      color: Color(0xFF6C757D),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Evaluators did not provide written feedback",
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: const Color(
                                        0xFF6C757D,
                                      ).withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
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
          const Text(
            "Loading Analytics...",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF002147),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudentSelected() {
    return Padding(
      padding: const EdgeInsets.all(32),
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
              Icons.analytics_outlined,
              size: 60,
              color: const Color(0xFF002147).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isMyEvaluation ? "No Performance Data" : "Select Student",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isMyEvaluation
                ? "Your performance data will appear here after evaluations"
                : "Choose a student from the dropdown to view their performance analytics",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF6C757D),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicator(
    int min,
    int max,
    String label,
    Color color,
  ) {
    bool isActive = percentage >= min && percentage <= max;
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : color.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$min-$max",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: isActive ? color : const Color(0xFF6C757D),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9,
            color: isActive ? color : const Color(0xFF6C757D),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
