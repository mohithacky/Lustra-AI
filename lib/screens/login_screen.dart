import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lustra_ai/home_screen.dart';
import 'package:lustra_ai/screens/shop_details_screen.dart';
import 'package:lustra_ai/services/auth_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/services/connectivity_service.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';
import 'package:lustra_ai/widgets/offline_dialog.dart';
import 'package:lustra_ai/widgets/wave_clipper.dart';
import 'package:lustra_ai/screens/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  String _mapAuthError(Object e) {
    if (e is! FirebaseAuthException) {
      return 'An unexpected error occurred. Please try again.';
    }
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'This email is already in use with a different sign-in method.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'operation-not-allowed':
        return 'Signing in with Google is not enabled. Please contact support.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your connection.';
      default:
        return 'An error occurred during sign-in. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppTheme.backgroundColor),
          ClipPath(
            clipper: WaveClipper(),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: GlassmorphicContainer(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/images/logo.png'),
                      backgroundColor: Colors.transparent,
                    ),
                    const SizedBox(height: 16),
                    Text('Lustra AI',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Your Personal AI Design Studio',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 64),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_isLoading)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      ElevatedButton.icon(
                        icon: Image.asset('assets/images/google_logo.png',
                            height: 24.0),
                        label: const Text('Continue with Google'),
                        onPressed: () async {
                          if (!await ConnectivityService.isConnected()) {
                            if (mounted) showOfflineDialog(context);
                            return;
                          }

                          setState(() {
                            _isLoading = true;
                            _errorMessage = null; // Clear previous error
                          });

                          try {
                            final result = await _auth.signInWithGoogle();
                            if (result != null && mounted) {
                              final bool isNewUser =
                                  result['isNewUser'] ?? false;
                              final bool shopDetailsFilled =
                                  result['shopDetailsFilled'] ?? false;

                              if (isNewUser) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(builder: (context) => OnboardingScreen()),
                                );
                              } else if (!shopDetailsFilled) {
                                Navigator.of(context).pushReplacementNamed(
                                    ShopDetailsScreen.routeName);
                              } else {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (context) => const HomeScreen()),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = _mapAuthError(e);
                              });
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
