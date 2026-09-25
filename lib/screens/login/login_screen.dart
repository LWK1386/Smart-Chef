import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Re-added your controller
  final AuthController authController = AuthController();
  bool isLoading = false;

  void _login() async {
    setState(() {
      isLoading = true;
    });

    // 1. Call your actual login logic
    await authController.loginWithGoogle();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    // 2. Check the login status and navigate
    if (authController.isLoggedIn.value) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The design stays the same, but now the logic is connected
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE0F7F1),
              Color(0xFFFFFFFF),
              Color(0xFFFFEAD2),
            ],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00A676)))
            : SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A676),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_menu, // Using a similar chef icon
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SmartChef',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D2D3D),
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'Cook Smart, Reduce Waste',
                style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              ),
              const SizedBox(height: 40),

              // Feature Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(Icons.eco, 'Plan meals & reduce food waste', const Color(0xFF4CAF50)),
                      const Divider(height: 1, indent: 60, endIndent: 20),
                      _buildFeatureRow(Icons.psychology, 'AI-powered recipe generation', const Color(0xFFFF9800)),
                      const Divider(height: 1, indent: 60, endIndent: 20),
                      _buildFeatureRow(Icons.people, 'Share recipes with community', const Color(0xFF9C27B0)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Google Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child:
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // UPDATED: Using local asset instead of Image.network
                        Image.asset(
                          'assets/google_logo.png',
                          height: 24,
                          width: 24,
                          // Optional: Handles cases where the image might be missing during dev
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Continue with Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87, // Ensures text is visible on white background
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 50),
                child: Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 16,
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2C3E50)),
            ),
          ),
        ],
      ),
    );
  }
}