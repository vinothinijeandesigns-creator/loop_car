import 'package:flutter/material.dart';

class DeleteAccountHelpSection extends StatelessWidget {
  final VoidCallback onUpdateProfile;
  final VoidCallback onContactUs;
  final VoidCallback onCommunicationPrefs;
  final VoidCallback onCloseAccount;
  final VoidCallback onCancel;

  const DeleteAccountHelpSection({
    super.key,
    required this.onUpdateProfile,
    required this.onContactUs,
    required this.onCommunicationPrefs,
    required this.onCloseAccount,
    required this.onCancel,
  });

  Widget _helpTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Color(0xFF00C6D2)),
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
        /// HELP CARD
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Can we help with something instead of closing your account?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),

                const SizedBox(height: 12),

                _helpTile(
                  icon: Icons.person_outline,
                  title: "Update profile",
                  subtitle: "Want to change your personal details?",
                  onTap: onUpdateProfile,
                ),

                const Divider(),

                _helpTile(
                  icon: Icons.support_agent,
                  title: "Contact Us",
                  subtitle: "Having technical issues?",
                  onTap: onContactUs,
                ),

                const Divider(),

                _helpTile(
                  icon: Icons.notifications_none,
                  title: "Communication preferences",
                  subtitle: "Receiving too many emails?",
                  onTap: onCommunicationPrefs,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        /// BUTTONS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// UPDATE BUTTON
            ElevatedButton(
              onPressed: onCloseAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Close Account"),
            ),

            const SizedBox(width: 20),

            /// CANCEL BUTTON
            ElevatedButton(
              onPressed: onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C6D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ],
    );
  }
}
