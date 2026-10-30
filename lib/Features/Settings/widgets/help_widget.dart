import 'package:flutter/material.dart';
import 'pdf_viewer.dart';

class HelpWidget extends StatelessWidget {
  const HelpWidget({super.key});

  void _openPdf(BuildContext context, String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(title: title, pdfUrl: url),
      ),
    );
  }

  Widget _helpTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF00C6D2)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// SEARCH
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search help articles",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        /// HELP CARD (same style as Delete Account)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Help topics",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),

                const SizedBox(height: 12),

                _helpTile(
                  icon: Icons.person,
                  title: "Passenger",
                  subtitle: "Learn how to book and manage rides",
                  onTap: () => _openPdf(
                    context,
                    "Passenger",
                    "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                  ),
                ),

                const Divider(),

                _helpTile(
                  icon: Icons.drive_eta,
                  title: "Driver",
                  subtitle: "Driver app guide and policies",
                  onTap: () => _openPdf(
                    context,
                    "Driver",
                    "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                  ),
                ),

                const Divider(),

                _helpTile(
                  icon: Icons.account_circle,
                  title: "Your Profile & Account",
                  subtitle: "Manage account details and settings",
                  onTap: () => _openPdf(
                    context,
                    "Profile & Account",
                    "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                  ),
                ),

                const Divider(),

                _helpTile(
                  icon: Icons.security,
                  title: "Trust, Safety & Accessibility",
                  subtitle: "Safety guidelines and accessibility features",
                  onTap: () => _openPdf(
                    context,
                    "Trust & Safety",
                    "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                  ),
                ),

                const Divider(),

                _helpTile(
                  icon: Icons.directions_car,
                  title: "About LoopCar",
                  subtitle: "Learn about the platform",
                  onTap: () => _openPdf(
                    context,
                    "About LoopCar",
                    "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
