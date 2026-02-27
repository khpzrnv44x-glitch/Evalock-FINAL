import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  // Global Key to ensure we can show SnackBars even if context is tricky
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> _launchEmail(BuildContext context) async {
    final email = Uri.encodeComponent('admin@corecslab.com');
    final subject = Uri.encodeComponent('University Portal Support Request');
    final body = Uri.encodeComponent('''
Student ID: [Please enter your student ID here]
Issue Description: [Please describe your issue in detail]

Contact Information:
Name: [Your Name]
Email: [Your Email]
Phone: [Your Phone Number]
''');

    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch email';
      }
    } catch (e) {
      _showErrorSnackBar(
        context,
        'Email app not found. Please email admin@corecslab.com manually.',
      );
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    const phoneNumber = '+923000437358';
    final uri = Uri.parse('tel:$phoneNumber');

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch dialer';
      }
    } catch (e) {
      _showErrorSnackBar(
        context,
        'Phone app not found. Number copied to clipboard.',
      );
    }
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phoneNumber = '923000437358';
    const message = 'Hello, I need assistance with the University Portal.';

    // Universal Link is the most reliable method for cross-version compatibility
    final uri = Uri.parse(
      'https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      _showErrorSnackBar(
        context,
        'WhatsApp not installed or could not be opened.',
      );
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: const Color(0xFF002147),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Contact Support",
          style: TextStyle(
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
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Response Time Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF002147),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Response Time",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "24-48 Hours",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "We aim to respond to all inquiries within this timeframe",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Contact Methods Title
                const Text(
                  "Contact Methods",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF002147),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Tap any option to contact support",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 16),

                // Email Card
                _buildContactCard(
                  icon: Icons.email_rounded,
                  title: "Email Support",
                  subtitle: "admin@corecslab.com",
                  description: "For technical issues and general inquiries",
                  color: const Color(0xFF002147),
                  onTap: () => _launchEmail(context),
                ),

                const SizedBox(height: 12),

                // Phone Card
                _buildContactCard(
                  icon: Icons.phone_rounded,
                  title: "Phone Support",
                  subtitle: "Hidden",
                  description: "Monday to Friday, 9 AM - 5 PM PKT",
                  color: const Color(0xFF27AE60),
                  onTap: () => _launchPhone(context),
                ),

                const SizedBox(height: 12),

                // WhatsApp Card
                _buildContactCard(
                  icon: Icons.chat_rounded,
                  title: "WhatsApp Support",
                  subtitle: "Hidden",
                  description: "Quick chat support for urgent issues",
                  color: const Color(0xFF25D366),
                  onTap: () => _launchWhatsApp(context),
                ),

                const SizedBox(height: 24),

                // Support Hours Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE9ECEF),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 20,
                            color: Color(0xFF002147),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "Support Hours",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF002147),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTimeSlot(
                        day: "Monday - Thursday",
                        time: "9:00 AM - 5:00 PM",
                      ),
                      _buildTimeSlot(day: "Friday", time: "9:00 AM - 1:00 PM"),
                      _buildTimeSlot(
                        day: "Saturday - Sunday",
                        time: "Emergency Only",
                        isEmergency: true,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "All times are in Pakistan Standard Time (PKT)",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Important Note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFDE047),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Color(0xFFCA8A04),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "For faster assistance:",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFCA8A04),
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: const TextSpan(
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Color(0xFF002147),
                                ),
                                children: [
                                  TextSpan(text: "• Include your Student ID\n"),
                                  TextSpan(
                                    text: "• Describe your issue in detail\n",
                                  ),
                                  TextSpan(
                                    text:
                                        "• Mention steps you've already tried",
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Alternative Contact Info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFE9ECEF),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Alternative Contact:",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF002147),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "For account or login issues, contact your university's IT department directly.",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF002147),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: const Color(0xFF6C757D),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF6C757D),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlot({
    required String day,
    required String time,
    bool isEmergency = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              day,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF002147),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isEmergency
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFF002147).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isEmergency
                    ? const Color(0xFFFECACA)
                    : const Color(0xFF002147).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isEmergency
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF002147),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
