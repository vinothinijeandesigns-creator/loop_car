import 'package:flutter/material.dart';
import '../../../config/supabase_config.dart';
import '../../../services/auth_service.dart';
import 'form_actions_button.dart';

class ChangePasswordSection extends StatefulWidget {
  final VoidCallback onCancel;

  const ChangePasswordSection({super.key, required this.onCancel});

  @override
  State<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  final TextEditingController currentController = TextEditingController();
  final TextEditingController newController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  Future<void> _sendResetEmail() async {
    setState(() => _isSaving = true);
    try {
      final currentUser = SupabaseConfig.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception("User not found or email missing");
      }

      await SupabaseConfig.auth.resetPasswordForEmail(currentUser.email!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset email sent! Check your inbox."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (newController.text != confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("New passwords do not match"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final currentUser = SupabaseConfig.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw Exception("User not found or email missing");
      }

      // Verify current password by attempting to sign in
      await SupabaseConfig.auth.signInWithPassword(
        email: currentUser.email!,
        password: currentController.text,
      );

      // Update to new password
      await AuthService().updatePassword(newController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password updated successfully"),
            backgroundColor: Colors.green,
          ),
        );
        currentController.clear();
        newController.clear();
        confirmController.clear();
        widget.onCancel(); // Close the section
      }
    } catch (e) {
      if (mounted) {
        // Typically throws AuthException with message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('Invalid login credentials') 
                ? "Incorrect current password" 
                : "Error updating password"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Text(
              "It must have at least 8 characters, 1 letter, 1 number and 1 special character.",
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            label: "Current password",
            controller: currentController,
            obscure: _obscureCurrent,
            toggle: () {
              setState(() => _obscureCurrent = !_obscureCurrent);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _sendResetEmail,
                child: const Text(
                  "Forgot Password?",
                  style: TextStyle(color: Color(0xFF00C6D2), fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildPasswordField(
            label: "New password",
            controller: newController,
            obscure: _obscureNew,
            toggle: () {
              setState(() => _obscureNew = !_obscureNew);
            },
            isNewPassword: true,
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            label: "Confirm",
            controller: confirmController,
            obscure: _obscureConfirm,
            toggle: () {
              setState(() => _obscureConfirm = !_obscureConfirm);
            },
          ),
          const SizedBox(height: 20),
          
          if (_isSaving)
            const Center(child: CircularProgressIndicator(color: Color(0xFF00C6D2)))
          else
            FormActionButtons(
              onUpdate: _updatePassword,
              onCancel: widget.onCancel,
            ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
    bool isNewPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Required";
          }
          if (isNewPassword) {
            // Regex for at least 8 chars, 1 letter, 1 number, 1 special character
            final regex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)(?=.*[^a-zA-Z\d\s]).{8,}$');
            if (!regex.hasMatch(value)) {
              return "Does not meet password requirements";
            }
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: toggle,
          ),
        ),
      ),
    );
  }
}
