import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lustra_ai/home_screen.dart';
import 'package:lustra_ai/screens/signup_screen.dart';
import 'package:lustra_ai/screens/shop_details_screen.dart';
import 'package:lustra_ai/services/auth_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';
import 'package:lustra_ai/widgets/wave_clipper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  final bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final result = await _auth.signInWithEmailAndPassword(
            _emailController.text, _passwordController.text);
        if (result != null && mounted) {
          if (result['shopDetailsFilled'] == true) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          } else {
            Navigator.of(context)
                .pushReplacementNamed(ShopDetailsScreen.routeName);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
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
                child: Form(
                  key: _formKey,
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
                      const SizedBox(height: 40),
                      Text(_isLogin ? 'Sign In' : 'Create Account',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration:
                            const InputDecoration(hintText: 'Email Address'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter an email' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(hintText: 'Password'),
                        obscureText: true,
                        validator: (value) => value!.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator(color: Colors.white)
                      else
                        ElevatedButton(
                          onPressed: _submit,
                          child: Text(_isLogin ? 'Continue' : 'Sign Up'),
                        ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          text: 'New user? ',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                          children: [
                            TextSpan(
                              text: 'Create an account',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const SignUpScreen(),
                                    ),
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Or',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Image.asset('assets/images/google_logo.png',
                            height: 24.0),
                        label: const Text('Continue with Google'),
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          try {
                            final result = await _auth.signInWithGoogle();
                            if (result != null && mounted) {
                              final bool isNewUser =
                                  result['isNewUser'] ?? false;
                              final bool shopDetailsFilled =
                                  result['shopDetailsFilled'] ?? false;

                              if (isNewUser || !shopDetailsFilled) {
                                Navigator.of(context).pushReplacementNamed(
                                    ShopDetailsScreen.routeName);
                              } else {
                                // Existing user with details filled, go to home screen which is the default
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                      builder: (context) => const HomeScreen()),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('An error occurred: $e')),
                              );
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
