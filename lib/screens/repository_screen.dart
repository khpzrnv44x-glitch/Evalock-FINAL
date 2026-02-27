import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class RepositoryScreen extends StatefulWidget {
  const RepositoryScreen({super.key});

  @override
  State<RepositoryScreen> createState() => _RepositoryScreenState();
}

class _RepositoryScreenState extends State<RepositoryScreen> {
  // Two lists: one for all data, one for search results
  List<dynamic> _allFiles = [];
  List<dynamic> _filteredFiles = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  final String apiBase = "https://your-corecslab-api.example.com";

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _searchController.addListener(_filterFiles);
  }

  // --- SEARCH LOGIC ---
  void _filterFiles() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFiles = _allFiles;
      } else {
        _filteredFiles = _allFiles.where((file) {
          return file['file_name'].toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // --- 1. FETCH FILES ---
  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiBase/get_repository.php'));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _allFiles = data;
          _filteredFiles = data; // Initialize filtered list
        });
      }
    } catch (e) {
      print("Error loading files: $e");
    }
    setState(() => _isLoading = false);
  }

  // --- 2. UPLOAD FILE ---
  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'ppt', 'pptx', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() => _isLoading = true);
      PlatformFile file = result.files.first;

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiBase/upload_file.php'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!),
        );
        request.fields['uploaded_by'] = "Student";

        var response = await request.send();

        if (response.statusCode == 200) {
          // Read response to check for server-side errors
          var respStr = await response.stream.bytesToString();
          var jsonResp = jsonDecode(respStr);

          if (jsonResp['status'] == 'success') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Upload Successful!"),
                backgroundColor: Colors.green,
              ),
            );
            _loadFiles(); // REFRESH LIST
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Upload Failed: ${jsonResp['message'] ?? 'Unknown error'}",
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Server Error"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // --- 3. DOWNLOAD FILE ---
  Future<void> _downloadFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open file")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Digital Repository",
          style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor: const Color(0xFF002147),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFiles),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search files...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Upload Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _uploadFile,
              icon: const Icon(Icons.cloud_upload),
              label: Text(
                _isLoading ? "Uploading..." : "Upload Presentation",
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002147),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          // Files List
          Expanded(
            child: _filteredFiles.isEmpty
                ? Center(
                    child: Text(_isLoading ? "Loading..." : "No files found."),
                  )
                : ListView.builder(
                    itemCount: _filteredFiles.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (ctx, i) {
                      var file = _filteredFiles[i];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file,
                              color: Colors.teal,
                            ),
                          ),
                          title: Text(
                            file['file_name'],
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            "By: ${file['uploaded_by']} • ${file['upload_time']}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.download_rounded,
                              color: Color(0xFF002147),
                            ),
                            onPressed: () => _downloadFile(file['file_path']),
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
