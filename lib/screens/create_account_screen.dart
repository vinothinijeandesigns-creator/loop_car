import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'welcome_commitment_screen.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final TextEditingController firstNameCtrl = TextEditingController();
  final TextEditingController lastNameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController confirmPasswordCtrl = TextEditingController();
  final TextEditingController dobCtrl = TextEditingController();
  final TextEditingController mobileCtrl = TextEditingController();

  DateTime? _selectedDob;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    confirmPasswordCtrl.dispose();
    dobCtrl.dispose();
    mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Format DOB for Supabase (YYYY-MM-DD)
      final formattedDob =
          _selectedDob != null
              ? "${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}"
              : '';

      final response = await _authService.signUp(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
        firstName: firstNameCtrl.text.trim(),
        lastName: lastNameCtrl.text.trim(),
        mobile: mobileCtrl.text.trim(),
        dob: formattedDob,
      );

      if (!mounted) return;

      if (response.user != null) {
        // Navigate to commitment screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeCommitmentPage()),
        );
      } else {
        setState(() {
          _errorMessage = 'Sign up failed. Please try again.';
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // Must be 18+
      initialDate: DateTime(2000),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0FC5D3)),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDob = date;
        dobCtrl.text = "${date.day}/${date.month}/${date.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0FC5D3),
      body: SafeArea(
        child: Column(
          children: [
            _header(),

            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFAF6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(),

                        const SizedBox(height: 24),

                        // Error Message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // First Name & Last Name
                        Row(
                          children: [
                            Expanded(
                              child: _inputField(
                                label: 'FIRST NAME',
                                controller: firstNameCtrl,
                                enabled: !_isLoading,
                                validator:
                                    (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _inputField(
                                label: 'LAST NAME',
                                controller: lastNameCtrl,
                                enabled: !_isLoading,
                                validator:
                                    (v) => v!.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Email
                        _inputField(
                          label: 'EMAIL',
                          controller: emailCtrl,
                          keyboard: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          validator: (v) {
                            if (v!.isEmpty) return 'Email required';
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$',
                            ).hasMatch(v)) {
                              return 'Enter valid email';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password
                        _inputField(
                          label: 'PASSWORD',
                          controller: passwordCtrl,
                          obscure: _obscurePassword,
                          enabled: !_isLoading,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Password required';
                            if (v.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Confirm Password
                        _inputField(
                          label: 'CONFIRM PASSWORD',
                          controller: confirmPasswordCtrl,
                          obscure: _obscureConfirmPassword,
                          enabled: !_isLoading,
                          suffix: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (v) {
                            if (v!.isEmpty) return 'Confirm your password';
                            if (v != passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Date of Birth
                        _inputField(
                          label: 'DATE OF BIRTH',
                          controller: dobCtrl,
                          readOnly: true,
                          enabled: !_isLoading,
                          hint: 'Select your date of birth',
                          suffixIcon: Icons.calendar_today,
                          validator: (v) => v!.isEmpty ? 'Select DOB' : null,
                          onTap: _isLoading ? null : _pickDate,
                        ),

                        const SizedBox(height: 16),

                        // Mobile
                        _inputField(
                          label: 'MOBILE',
                          controller: mobileCtrl,
                          keyboard: TextInputType.phone,
                          enabled: !_isLoading,
                          validator: (v) {
                            if (v!.isEmpty) return 'Mobile required';
                            if (v.length != 10) {
                              return 'Enter 10-digit number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 32),

                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0FC5D3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'LoopCar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Ride. Laugh. Repeat. For Less!',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _title() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Create new\nAccount',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              'Already Registered? Log in here.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF0FC5D3),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
    bool readOnly = false,
    bool enabled = true,
    TextInputType keyboard = TextInputType.text,
    IconData? suffixIcon,
    Widget? suffix,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          readOnly: readOnly,
          enabled: enabled,
          keyboardType: keyboard,
          validator: validator,
          onTap: onTap,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? const Color(0xFFD9D6D3) : Colors.grey.shade200,
            suffixIcon:
                suffix ??
                (suffixIcon != null ? Icon(suffixIcon, size: 18) : null),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
