import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/home_screen.dart';

class NewShopDetailsScreen extends StatefulWidget {
  static const String routeName = '/new-shop-details';

  const NewShopDetailsScreen({Key? key}) : super(key: key);

  @override
  _NewShopDetailsScreenState createState() => _NewShopDetailsScreenState();
}

class _NewShopDetailsScreenState extends State<NewShopDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  File? _logoFile;
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _instagramIdController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _isPhoneVerifying = false;
  bool _isPhoneVerified = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _phoneNumberController.dispose();
    _instagramIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tell us about your shop'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(labelText: 'Shop Name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shopAddressController,
                decoration: const InputDecoration(labelText: 'Shop Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                onChanged: (_) {
                  setState(() {
                    _isPhoneVerified = false;
                  });
                },
                onFieldSubmitted: (_) {
                  _startPhoneVerification();
                },
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed:
                        _isPhoneVerifying ? null : _startPhoneVerification,
                    child: Text(
                      _isPhoneVerified ? 'Phone Verified' : 'Verify Phone',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _instagramIdController,
                decoration: const InputDecoration(labelText: 'Instagram ID'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              if (_logoFile != null)
                Image.file(
                  _logoFile!,
                  height: 100,
                ),
              ElevatedButton.icon(
                onPressed: _pickLogo,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add Logo'),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      if (!_isPhoneVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please verify your phone number before submitting')),
        );
        return;
      }

      String? logoUrl;
      if (_logoFile != null) {
        logoUrl = await _firestoreService.uploadShopLogo(_logoFile!);
      }

      await _firestoreService.addShopDetails(
        _shopNameController.text,
        _shopAddressController.text,
        _phoneNumberController.text,
        logoUrl,
        _instagramIdController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  Future<void> _pickLogo() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _startPhoneVerification() async {
    final phone = _phoneNumberController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() {
      _isPhoneVerifying = true;
    });

    try {
      final taken = await _firestoreService.isPhoneNumberTaken(phone);
      if (taken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('This phone number is already in use')),
          );
        }
        setState(() {
          _isPhoneVerifying = false;
          _isPhoneVerified = false;
        });
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final user = _auth.currentUser;
            if (user != null) {
              await user.linkWithCredential(credential);
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Phone number verified')),
              );
            }
            setState(() {
              _isPhoneVerified = true;
            });
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Failed to link phone number to account')),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Verification failed: ${e.message ?? 'Unknown error'}')),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
          });
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error verifying phone: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPhoneVerifying = false;
        });
      }
    }
  }

  Future<void> _showOtpDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter OTP'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'OTP',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final smsCode = controller.text.trim();
                if (_verificationId == null || smsCode.isEmpty) {
                  return;
                }

                try {
                  final credential = PhoneAuthProvider.credential(
                    verificationId: _verificationId!,
                    smsCode: smsCode,
                  );
                  final user = _auth.currentUser;
                  if (user != null) {
                    await user.linkWithCredential(credential);
                  }
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone number verified')),
                    );
                  }
                  setState(() {
                    _isPhoneVerified = true;
                  });
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid OTP')),
                    );
                  }
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }
}
