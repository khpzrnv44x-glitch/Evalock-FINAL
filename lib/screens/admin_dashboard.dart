import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db/database_helper.dart';

class AdminDashboard extends StatefulWidget {
  final String presentationId;
  const AdminDashboard({super.key, required this.presentationId});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> downloadLogs = [];
  List<Map<String, dynamic>> studentStats = [];
  bool isLoading = true;

  // --- Search Controller ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final dbLogs = await DatabaseHelper.instance.getAdminLogs();
    final dbStats = await DatabaseHelper.instance.getTeacherQueryB(
      widget.presentationId,
    );

    if (mounted) {
      setState(() {
        downloadLogs = dbLogs;
        studentStats = dbStats;
        isLoading = false;
      });
    }
  }

  String _formatTime(String utcTime) {
    try {
      DateTime dt = DateTime.parse(
        utcTime,
      ).toUtc().add(const Duration(hours: 5));
      return "${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}";
    } catch (e) {
      return utcTime;
    }
  }

  Color _getColor(double p) {
    if (p >= 80) return const Color(0xFF27AE60); // Green
    if (p >= 60) return const Color(0xFF3498DB); // Blue
    if (p >= 40) return const Color(0xFFF39C12); // Orange
    return const Color(0xFFE74C3C); // Red
  }

  void _showStudentDetail(Map<String, dynamic> studentData) {
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
      builder: (ctx) => StudentDetailSheet(
        studentData: studentData,
        presentationId: widget.presentationId,
        colorHelper: _getColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(),
      body: isLoading
          ? _buildLoadingState()
          : TabBarView(
              controller: _tabController,
              children: [_buildDownloadsTab(), _buildEvaluationsTab()],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Admin Dashboard",
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
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: const Color(0xFF002147),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.download_rounded, size: 20),
                text: "Downloads",
              ),
              Tab(
                icon: Icon(Icons.assessment_rounded, size: 20),
                text: "Evaluations",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        color: const Color(0xFF002147),
        backgroundColor: const Color.fromARGB(
          255,
          73,
          116,
          165,
        ).withOpacity(0.1),
      ),
    );
  }

  Widget _buildDownloadsTab() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            "Total Downloads",
            downloadLogs.length.toString(),
            Icons.download_rounded,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: downloadLogs.isEmpty
                ? _buildEmptyState(
                    "No download logs yet",
                    Icons.download_done_rounded,
                  )
                : ListView.separated(
                    itemCount: downloadLogs.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (c, i) => _buildLogItem(downloadLogs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH & LIST ---
  Widget _buildEvaluationsTab() {
    final filteredStats = studentStats.where((s) {
      final name = s['evaluated_student']?.toString().toLowerCase() ?? "";
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatCard(
            "Total Evaluations",
            studentStats.length.toString(),
            Icons.assessment_rounded,
          ),
          const SizedBox(height: 16),

          // Search Box
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9ECEF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF002147),
              ),
              decoration: const InputDecoration(
                hintText: "Search student...",
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Color(0xFF6C757D),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6C757D),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: filteredStats.isEmpty
                ? _buildEmptyState(
                    _searchQuery.isEmpty
                        ? "No evaluation data yet"
                        : "No student found",
                    Icons.assessment_outlined,
                  )
                : ListView.separated(
                    itemCount: filteredStats.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (c, i) => _buildStudentItem(filteredStats[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF002147).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: const Color(0xFF002147), size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF6C757D),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF002147),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF27AE60),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['user_email'],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF002147),
                  ),
                ),
                Text(
                  _formatTime(log['download_time']),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentItem(Map<String, dynamic> s) {
    double percentage = s['percentage']?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showStudentDetail(s),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getColor(percentage).withOpacity(0.2),
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  "${percentage.toStringAsFixed(0)}%",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getColor(percentage),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['evaluated_student'],
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF002147),
                    ),
                  ),
                  const Text(
                    "Tap to view details",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF002147)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF6C757D).withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// STUDENT DETAIL SHEET (UPDATED TO GEMINI API)
// ---------------------------------------------------------
class StudentDetailSheet extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String presentationId;
  final Color Function(double) colorHelper;

  const StudentDetailSheet({
    super.key,
    required this.studentData,
    required this.presentationId,
    required this.colorHelper,
  });

  @override
  State<StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<StudentDetailSheet> {
  List<Map<String, dynamic>> comments = [];
  String aiAnalysis = "Loading AI analysis...";
  bool isAiLoading = true;

  // 1. UPDATED API KEY (GEMINI)
  final String _apiKey = "YOUR_GEMINI_API_KEY";

  @override
  void initState() {
    super.initState();
    _fetchDetailsAndAI();
  }

  Future<void> _fetchDetailsAndAI() async {
    // 1. Fetch Comments
    String studentId = widget.studentData['evaluated_student'];
    var fetchedComments = await DatabaseHelper.instance.getStudentComments(
      widget.presentationId,
      studentId,
    );

    if (mounted) {
      setState(() {
        comments = fetchedComments;
      });
    }

    // 2. Call Real-Time AI (Gemini)
    await _generateGeminiAnalysis(fetchedComments);
  }

  // 2. UPDATED AI FUNCTION (Matches PresentationStatsScreen)
  Future<void> _generateGeminiAnalysis(
    List<Map<String, dynamic>> fetchedComments,
  ) async {
    double percentage = widget.studentData['percentage'];

    String commentText = fetchedComments.isEmpty
        ? "No written comments."
        : fetchedComments.map((c) => "${c['feedback_text']}").join(". ");

    // Smart Prompt
    String prompt =
        """
      Role: Academic Evaluator.
      Task: Summarize student performance (Max 40 words).
      Data: Score $percentage%, Comments: $commentText
      
      Logic:
      1. If specific advice exists (e.g. 'database error'), mention it clearly.
      2. If comments are generic/missing:
         - Score < 50%: Critical improvement needed.
         - Score > 80%: Excellent work.
      3. Speak directly to the student.
    """;

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
          "generationConfig": {"temperature": 0.5, "maxOutputTokens": 300},
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String text =
            data['candidates']?[0]['content']?['parts']?[0]['text'] ??
            "AI analysis unavailable.";
        if (mounted) {
          setState(() {
            aiAnalysis = text.trim();
            isAiLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            aiAnalysis = "AI Error: ${response.statusCode}";
            isAiLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiAnalysis = "Connection Error (Offline Mode)";
          isAiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double percentage = widget.studentData['percentage'];
    Color bubbleColor = widget.colorHelper(percentage);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Student Details",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF002147),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Color(0xFF002147)),
              ),
            ],
          ),

          // COMPACT ROW (ID + Smaller Bubble)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9ECEF)),
            ),
            child: Row(
              children: [
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Student ID",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                      Text(
                        widget.studentData['evaluated_student'],
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF002147),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Smaller Bubble (80x80)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: bubbleColor.withOpacity(0.3),
                      width: 6,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "${percentage.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: bubbleColor,
                          ),
                        ),
                        const Text(
                          "Score",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Gemini AI Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  color: Color(0xFFD4AF37),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: isAiLoading
                      ? const Text(
                          "Consulting Gemini AI...",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Text(
                          aiAnalysis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            "Feedback Comments",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 8),

          // LIST of Comments
          Expanded(
            child: comments.isEmpty
                ? const Center(
                    child: Text(
                      "No comments found",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (c, i) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE9ECEF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: const Color(0xFF002147).withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  comments[i]['evaluated_by'],
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF002147),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comments[i]['feedback_text'],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: Color(0xFF495057),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
