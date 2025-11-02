import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/services/auth_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';
import 'package:lustra_ai/widgets/wave_clipper.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  File? _shopLogo;

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _shopLogo = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
          shopName: _shopNameController.text,
          shopAddress: _shopAddressController.text,
          phoneNumber: _phoneNumberController.text,
          shopLogo: _shopLogo,
        );

        // Get the current user
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
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
                      Text('Create Account',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: Colors.white)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(hintText: 'Email Address'),
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
                      ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shopNameController,
                          decoration:
                              const InputDecoration(hintText: 'Shop Name'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter your shop name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _shopAddressController,
                          decoration:
                              const InputDecoration(hintText: 'Shop Address'),
                          validator: (value) => value!.isEmpty
                              ? 'Please enter your shop address'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneNumberController,
                          decoration:
                              const InputDecoration(hintText: 'Phone Number'),
                          keyboardType: TextInputType.phone,
                          validator: (value) => value!.isEmpty
                              ? 'Please enter your phone number'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _pickImage,
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white70),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: _shopLogo != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(_shopLogo!,
                                            fit: BoxFit.cover),
                                      )
                                    : const Icon(Icons.add_a_photo,
                                        color: Colors.white70),
                              ),
                              const SizedBox(width: 16),
                              const Text('Add your Shop\'s logo',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator(color: Colors.white)
                      else
                        ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Sign Up'),
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
