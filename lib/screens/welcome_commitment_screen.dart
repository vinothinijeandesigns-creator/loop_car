import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

class WelcomeCommitmentPage extends StatefulWidget {
  const WelcomeCommitmentPage({super.key});

  @override
  State<WelcomeCommitmentPage> createState() => _WelcomeCommitmentPageState();
}

class _WelcomeCommitmentPageState extends State<WelcomeCommitmentPage> {
  final _authService = AuthService();

  bool isAgreed = false;
  bool _isLoading = false;
  String? _userName;

  final List<Map<String, dynamic>> commitments = [
    {
      'icon': Icons.access_time,
      'text': 'Be On Time – Respect everyone\'s schedule',
    },
    {
      'icon': Icons.check_circle,
      'text': 'Honor Your Booking – Cancel only when necessary',
    },
    {
      'icon': Icons.people,
      'text': 'Be Friendly – Create a welcoming atmosphere',
    },
    {
      'icon': Icons.security,
      'text': 'Drive Safely – Safety is our top priority',
    },
    {
      'icon': Icons.eco,
      'text': 'Go Green – Every shared ride helps the planet',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final profile = await _authService.getCurrentProfile();
      if (mounted && profile != null) {
        setState(() {
          _userName = profile['first_name'] ?? 'User';
        });
      }
    } catch (e) {
      // Ignore errors, use default
    }
  }

  Future<void> _handleSubmit() async {
    if (!isAgreed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Try to save commitment acceptance to profile (non-blocking)
      await _authService.acceptCommitment();
    } catch (e) {
      // Ignore errors - commitment save is not critical
      debugPrint('Commitment save failed: $e');
    }

    if (!mounted) return;

    // Always navigate to home screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00C6D2),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ),

            const SizedBox(height: 16),

            // Body
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFAF6),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Welcome text with user name
                      Text(
                        'Welcome${_userName != null ? ', $_userName' : ''}!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C6D2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'YOUR CARPOOL COMMITMENT',
                          style: TextStyle(
                            letterSpacing: 1.2,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00C6D2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Commitment Card with actual items
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children:
                              commitments.map((commitment) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF00C6D2,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          commitment['icon'] as IconData,
                                          color: const Color(0xFF00C6D2),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          commitment['text'] as String,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Motivational text
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00C6D2).withOpacity(0.1),
                              const Color(0xFF00C6D2).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: const [
                            Text(
                              '🚗 Carpool Today',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Save Fuel • Save Money • Save Earth',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '❤️ One ride at a time, we make the world better!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Agree Checkbox
                      InkWell(
                        onTap:
                            _isLoading
                                ? null
                                : () {
                                  setState(() => isAgreed = !isAgreed);
                                },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isAgreed
                                    ? const Color(0xFF00C6D2).withOpacity(0.1)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  isAgreed
                                      ? const Color(0xFF00C6D2)
                                      : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isAgreed,
                                onChanged:
                                    _isLoading
                                        ? null
                                        : (value) {
                                          setState(() => isAgreed = value!);
                                        },
                                activeColor: const Color(0xFF00C6D2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const Expanded(
                                child: Text(
                                  'I agree to follow the LoopCar Community Guidelines',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed:
                              isAgreed && !_isLoading ? _handleSubmit : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C6D2),
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isAgreed ? 2 : 0,
                          ),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
