import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_models.dart';
import '../db/database_helper.dart';
import 'evaluation_screen.dart';
import 'login_screen.dart';
import 'admin_dashboard.dart';
import 'presentation_stats_screen.dart';
import 'profile_screen.dart';
import 'contact_screen.dart';
import 'create_presentation_screen.dart';
// THESE IMPORTS WILL NOW WORK because the files actually have the right classes
import 'preparation_screen.dart';
import 'repository_screen.dart';
import 'developer_screen.dart';

class PresentationListScreen extends StatefulWidget {
  const PresentationListScreen({super.key});
  @override
  State<PresentationListScreen> createState() => _PresentationListScreenState();
}

class _PresentationListScreenState extends State<PresentationListScreen> {
  final String apiBase = "https://your-corecslab-api.example.com";
  final String studentApi = "https://your-student-api.example.com";

  List<Presentation> presentations = [];
  List<Presentation> filteredPresentations = [];
  bool isLoading = true;
  String myName = "User";
  String myEmail = "";
  bool isAdmin = false;
  final String adminEmail = "admin@yourdomain.com";
  final ValueNotifier<String?> profileImageNotifier = ValueNotifier<String?>(
    null,
  );
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_filterPresentations);
  }

  void _filterPresentations() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        filteredPresentations = presentations;
      });
    } else {
      setState(() {
        filteredPresentations = presentations
            .where(
              (presentation) =>
                  presentation.description.toLowerCase().contains(query),
            )
            .toList();
      });
    }
  }

  Future<void> _loadInitialData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('my_email') ?? "";

    setState(() {
      myName = prefs.getString('my_name') ?? "User";
      myEmail = email;
      isAdmin = email == adminEmail;
      profileImageNotifier.value = prefs.getString('profile_image');
    });

    var localPresentations = await DatabaseHelper.instance
        .getLocalPresentations();
    if (localPresentations.isNotEmpty) {
      setState(() {
        presentations = localPresentations;
        filteredPresentations = localPresentations;
        isLoading = false;
      });
      _reloadData(isAuto: true);
    } else {
      _reloadData(isAuto: false);
    }
  }

  // --- UPDATED: Toggle Visibility (Syncs to Server) ---
  void _toggleVisibility(Presentation item) async {
    int newValue = item.isVisible == 1 ? 0 : 1;

    // 1. Update Local UI Immediately (Optimistic UI)
    await DatabaseHelper.instance.updatePresentationVisibility(
      item.id,
      newValue,
    );
    _refreshLocalList();

    // 2. Send to Server
    try {
      await http.post(
        Uri.parse('$apiBase/update_presentation_status.php'),
        body: {
          'id': item.id,
          'type': 'visibility',
          'value': newValue.toString(),
        },
      );
    } catch (e) {
      print("Failed to sync visibility to server: $e");
    }
  }

  // --- UPDATED: Toggle Results (Syncs to Server) ---
  void _toggleResults(Presentation item) async {
    int newValue = item.areResultsVisible == 1 ? 0 : 1;

    // 1. Update Local UI Immediately
    await DatabaseHelper.instance.updateResultVisibility(item.id, newValue);
    _refreshLocalList();

    // 2. Send to Server
    try {
      await http.post(
        Uri.parse('$apiBase/update_presentation_status.php'),
        body: {'id': item.id, 'type': 'results', 'value': newValue.toString()},
      );
    } catch (e) {
      print("Failed to sync results to server: $e");
    }
  }

  Future<void> _refreshLocalList() async {
    var localPresentations = await DatabaseHelper.instance
        .getLocalPresentations();
    if (mounted) {
      setState(() {
        presentations = localPresentations;
        filteredPresentations = localPresentations;
        // Re-apply search filter if active
        if (_searchController.text.isNotEmpty) {
          _filterPresentations();
        }
      });
    }
  }

  Future<void> _reloadData({bool isAuto = false}) async {
    if (!isAuto) setState(() => isLoading = true);
    try {
      final futures = [
        if (!isAuto)
          http.post(
            Uri.parse('$apiBase/log_download.php'),
            body: {'email': myEmail},
          )
        else
          Future.value(null),
        http.get(Uri.parse('$studentApi/student_data?my_id=0')),
        http.get(Uri.parse('$apiBase/get_presentations.php')),
        http.get(Uri.parse('$apiBase/get_presentation_codes.php')),
        http.get(Uri.parse('$apiBase/get_criteria.php')),
        http.get(Uri.parse('$apiBase/get_evaluations.php')),
        http.get(Uri.parse('$apiBase/get_downloads.php')),
      ];

      final results = await Future.wait(futures);
      final sResp = results[1] as http.Response;
      final pResp = results[2] as http.Response;
      final cResp = results[3] as http.Response;
      final critResp = results[4] as http.Response;
      final evalResp = results[5] as http.Response;
      final logResp = results[6] as http.Response;

      if (sResp.statusCode == 200) {
        var json = jsonDecode(sResp.body);
        List<dynamic> list = (json is Map) ? json['data'] : json;
        await DatabaseHelper.instance.clearAndInsert(
          'students',
          list
              .map(
                (e) => {
                  'id': (e['id'] ?? e['user_id']).toString(),
                  'name': e['full_name'] ?? e['user_full_name'] ?? e['name'],
                  'email': e['email'] ?? e['user_email'],
                  'roll_no': e['rollno'] ?? e['roll_no'] ?? '',
                },
              )
              .toList(),
        );
      }

      if (pResp.statusCode == 200) {
        List pJson = jsonDecode(pResp.body);
        List<Map<String, dynamic>> pRows = pJson.cast<Map<String, dynamic>>();
        await DatabaseHelper.instance.clearAndInsert('presentations', pRows);
        if (mounted) {
          _refreshLocalList();
        }
      }

      if (cResp.statusCode == 200)
        await DatabaseHelper.instance.clearAndInsert(
          'presentation_codes',
          jsonDecode(cResp.body).cast<Map<String, dynamic>>(),
        );
      if (critResp.statusCode == 200)
        await DatabaseHelper.instance.clearAndInsert(
          'presentation_criteria',
          jsonDecode(critResp.body).cast<Map<String, dynamic>>(),
        );
      if (evalResp.statusCode == 200)
        await DatabaseHelper.instance.clearAndInsert(
          'student_evaluation',
          jsonDecode(evalResp.body).cast<Map<String, dynamic>>(),
        );
      if (logResp.statusCode == 200)
        await DatabaseHelper.instance.clearAndInsert(
          'download_logs',
          jsonDecode(logResp.body).cast<Map<String, dynamic>>(),
        );

      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Synced & Updated!"),
            backgroundColor: Color(0xFF002147),
          ),
        );
      }
    } catch (e) {
      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sync Error: $e"),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _showCodeDialog(String pid, String pName) {
    TextEditingController codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter Room Code",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF002147),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                ),
                child: TextField(
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Color(0xFF002147),
                  ),
                  decoration: const InputDecoration(
                    hintText: "Enter the presentation code",
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF6C757D),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF002147),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6C757D),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      bool isValid = await DatabaseHelper.instance.validateCode(
                        pid,
                        codeCtrl.text.trim(),
                      );
                      if (isValid) {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => EvaluationScreen(
                              presentationId: pid,
                              presentationName: pName,
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Invalid code. Please try again."),
                            backgroundColor: Color(0xFFE74C3C),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002147),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      "JOIN",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
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
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      floatingActionButton: _buildFloatingActionButton(),
      body: isLoading
          ? _buildLoadingState()
          : Column(
              children: [
                _buildUserBanner(),
                _buildSearchBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredPresentations.isEmpty
                      ? (filteredPresentations.isEmpty &&
                                _searchController.text.isNotEmpty
                            ? _buildNoResultsState()
                            : _buildEmptyState())
                      : _buildPresentationsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 300,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFE9ECEF), width: 1)),
        ),
        child: Column(
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF002147),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ValueListenableBuilder<String?>(
                          valueListenable: profileImageNotifier,
                          builder: (ctx, path, _) => Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: path != null
                                  ? Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 30,
                                        color: Colors.white,
                                      ),
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
                                myName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                myEmail,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isAdmin)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 12,
                                        color: Color(0xFFD4AF37),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Admin",
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  _buildDrawerItem(
                    icon: Icons.person_outline_rounded,
                    title: "Profile",
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const ProfileScreen(),
                        ),
                      );
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      profileImageNotifier.value = prefs.getString(
                        'profile_image',
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.auto_awesome,
                    title: "AI Preparation",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const PreparationScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.cloud_download_rounded,
                    title: "Digital Repository",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const RepositoryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: "Developer Info",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const DeveloperScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.contact_support_outlined,
                    title: "Contact Support",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const ContactScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.sync_rounded,
                    title: "Sync Data",
                    onTap: () {
                      Navigator.pop(context);
                      _reloadData();
                    },
                  ),
                  const Divider(
                    height: 40,
                    thickness: 1,
                    color: Color(0xFFE9ECEF),
                    indent: 20,
                    endIndent: 20,
                  ),
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    onTap: () async {
                      Navigator.pop(context);
                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs.clear();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (c) => const LoginScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF002147).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF002147)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF002147),
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        "Presentations",
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
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => _reloadData(),
            color: Colors.white,
            tooltip: "Refresh Data",
          ),
        ),
        Container(
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => const CreatePresentationScreen(),
                ),
              ).then((_) {
                _reloadData();
              });
            },
            color: Colors.white,
            tooltip: "Create Presentation",
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => const CreatePresentationScreen()),
        ).then((_) {
          _reloadData();
        });
      },
      backgroundColor: const Color(0xFF002147),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 28),
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
            "Loading Presentations...",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Fetching latest data from server",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF002147),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, size: 24, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  myName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  myEmail,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 12,
                    color: Color(0xFFD4AF37),
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Admin",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF002147),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: Color(0xFF6C757D)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF002147),
              ),
              decoration: const InputDecoration(
                hintText: "Search presentations...",
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF6C757D),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              color: const Color(0xFF6C757D),
              onPressed: () {
                _searchController.clear();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Color(0xFF6C757D)),
          SizedBox(height: 16),
          Text(
            "No presentations found",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF002147),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Try a different search term",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF6C757D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.slideshow_outlined,
              size: 60,
              color: const Color(0xFF002147).withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Presentations Available",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAdmin
                ? "Create your first presentation to get started"
                : "Synchronize data to load presentations",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Color(0xFF6C757D),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isAdmin)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => const CreatePresentationScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                "Create Presentation",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002147),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _reloadData(),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text(
                "Sync Now",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002147),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPresentationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredPresentations.length,
      itemBuilder: (context, index) {
        final item = filteredPresentations[index];
        bool isCreator =
            (item.creatorEmail != null && item.creatorEmail == myEmail);
        bool hasControl = isAdmin || isCreator; // Admin or Creator has control

        // --- FILTERING LOGIC ---
        // If presentation is HIDDEN (0) and user is NOT Admin/Creator, hide it completely.
        if (item.isVisible == 0 && !hasControl) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            elevation: 0,
            color: Colors.white,
            child: InkWell(
              onTap: () => _showCodeDialog(item.id, item.description),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.description,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF002147),
                            ),
                          ),
                        ),
                        // Show "HIDDEN" badge if user has control and item is hidden
                        if (hasControl && item.isVisible == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "HIDDEN",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tap 'Join' to enter with code",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF6C757D),
                      ),
                    ),

                    // --- ADMIN / CREATOR CONTROLS ---
                    if (hasControl) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Visibility Toggle
                          Row(
                            children: [
                              Switch(
                                value: item.isVisible == 1,
                                activeColor: const Color(0xFF27AE60),
                                onChanged: (_) => _toggleVisibility(item),
                              ),
                              Text(
                                item.isVisible == 1 ? "Visible" : "Hidden",
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          // Result Release Toggle
                          Row(
                            children: [
                              Switch(
                                value: item.areResultsVisible == 1,
                                activeColor: const Color(0xFF27AE60),
                                onChanged: (_) => _toggleResults(item),
                              ),
                              Text(
                                item.areResultsVisible == 1
                                    ? "Results Released"
                                    : "Results Locked",
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE9ECEF)),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (c) =>
                                    AdminDashboard(presentationId: item.id),
                              ),
                            ),
                            icon: const Icon(
                              Icons.admin_panel_settings_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              "Admin",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF002147),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),

                        // REMOVED THE "RESULTS" BUTTON HERE AS REQUESTED
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => PresentationStatsScreen(
                                presentationId: item.id,
                                presentationName: item.description,
                                isMyEvaluation: true,
                                // PASSING RESULT VISIBILITY STATUS
                                areResultsReleased: item.areResultsVisible == 1,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.person_rounded, size: 16),
                          label: const Text(
                            "My Stats",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF002147),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),

                        ElevatedButton.icon(
                          onPressed: () =>
                              _showCodeDialog(item.id, item.description),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF002147),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.login_rounded, size: 16),
                          label: const Text(
                            "Join",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
