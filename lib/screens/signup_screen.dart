import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _rollNoCtrl = TextEditingController();
  final _cellCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  String? _validateInputs() {
    if (_nameCtrl.text.isEmpty ||
        _rollNoCtrl.text.isEmpty ||
        _cellCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) {
      return "Please fill all required fields";
    }

    final emailRegex = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!emailRegex.hasMatch(_emailCtrl.text)) {
      return "Please enter a valid university email address";
    }

    final phoneRegex = RegExp(r"^\+92\d{10}$");
    if (!phoneRegex.hasMatch(_cellCtrl.text)) {
      return "Phone must be in format: +923001234567";
    }

    String pass = _passCtrl.text;
    if (pass.length < 8) {
      return "Password must be at least 8 characters";
    }
    if (!pass.contains(RegExp(r'[A-Z]'))) {
      return "Password must contain at least one uppercase letter";
    }
    if (!pass.contains(RegExp(r'[0-9]'))) {
      return "Password must contain at least one number";
    }
    if (!pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      return "Password must contain at least one special character";
    }

    if (_passCtrl.text != _confirmPassCtrl.text) {
      return "Passwords do not match";
    }

    return null;
  }

  Future<void> _registerUser() async {
    FocusScope.of(context).unfocus();

    String? error = _validateInputs();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
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

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        "https://your-student-api.example.com/submit_registration",
      );
      final requestUrl = url.replace(
        queryParameters: {
          'full_name': _nameCtrl.text.trim(),
          'roll_no': _rollNoCtrl.text.trim(),
          'cellno': _cellCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text.trim(),
        },
      );

      final response = await http.post(requestUrl);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Registration successful! Please login with your credentials",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Registration failed. Please check your information and try again",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: const Color(0xFFE74C3C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Network error: ${e.toString()}",
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: const Color(0xFF002147),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: const Color(0xFF6C757D),
                ),
                prefixIcon: Container(
                  width: 48,
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: const Color(0xFF002147)),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    bool isConfirm = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              obscureText: isConfirm
                  ? !_isConfirmPasswordVisible
                  : !_isPasswordVisible,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: const Color(0xFF002147),
              ),
              decoration: InputDecoration(
                hintText: "Enter your ${label.toLowerCase()}",
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: const Color(0xFF6C757D),
                ),
                prefixIcon: Container(
                  width: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 20,
                    color: const Color(0xFF002147),
                  ),
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      if (isConfirm) {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      } else {
                        _isPasswordVisible = !_isPasswordVisible;
                      }
                    });
                  },
                  icon: Icon(
                    isConfirm
                        ? _isConfirmPasswordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded
                        : _isPasswordVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                    color: const Color(0xFF6C757D),
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final password = _passCtrl.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Password Requirements",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF002147),
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirementCheck("At least 8 characters", password.length >= 8),
          _buildRequirementCheck(
            "One uppercase letter (A-Z)",
            password.contains(RegExp(r'[A-Z]')),
          ),
          _buildRequirementCheck(
            "One number (0-9)",
            password.contains(RegExp(r'[0-9]')),
          ),
          _buildRequirementCheck(
            "One special character (!@#...)",
            password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementCheck(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isMet
                  ? const Color(0xFF27AE60)
                  : const Color(0xFF6C757D).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isMet ? Icons.check_rounded : Icons.close_rounded,
                size: 12,
                color: isMet
                    ? Colors.white
                    : const Color(0xFF6C757D).withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: isMet ? const Color(0xFF27AE60) : const Color(0xFF6C757D),
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
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
          "Create Student Account",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002147),
        elevation: 0,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF002147).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 48,
                      color: const Color(0xFF002147),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Join University Portal",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF002147),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your student account to access presentations and evaluations",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: const Color(0xFF6C757D),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Personal Information Section
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Text(
                "Personal Information",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF002147),
                ),
              ),
            ),

            _buildTextField(
              controller: _nameCtrl,
              label: "Full Name",
              icon: Icons.person_outline_rounded,
              hintText: "Enter your full name",
            ),
            _buildTextField(
              controller: _rollNoCtrl,
              label: "University Roll Number",
              icon: Icons.badge_outlined,
              hintText: "e.g., BSCSF23M34",
            ),
            _buildTextField(
              controller: _cellCtrl,
              label: "Mobile Number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              hintText: "+923001234567",
            ),
            _buildTextField(
              controller: _emailCtrl,
              label: "University Email",
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              hintText: "student@university.edu.pk",
            ),

            const SizedBox(height: 8),

            // Account Security Section
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Text(
                "Account Security",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF002147),
                ),
              ),
            ),

            _buildPasswordField(controller: _passCtrl, label: "Password"),

            // Dynamic Password Requirements
            if (_passCtrl.text.isNotEmpty) _buildPasswordRequirements(),

            _buildPasswordField(
              controller: _confirmPassCtrl,
              label: "Confirm Password",
              isConfirm: true,
            ),

            // Terms and Conditions
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF002147).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: const Color(0xFF002147),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "By registering, you agree to our Terms of Service and Privacy Policy. All data is protected under university security protocols.",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: const Color(0xFF6C757D),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Register Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002147),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        "CREATE STUDENT ACCOUNT",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Back to Login
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF002147),
                  textStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text("Already have an account? Sign in"),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rollNoCtrl.dispose();
    _cellCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }
}
