import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/models/onboarding_data.dart';
import 'package:lustra_ai/services/firestore_service.dart';

class ShopDetailsScreen extends StatefulWidget {
  static const String routeName = '/shop-details';

  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const ShopDetailsScreen({
    Key? key,
    required this.onboardingData,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  _ShopDetailsScreenState createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _instagramIdController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _isPhoneVerifying = false;
  bool _isPhoneVerified = false;
  bool _isOtpVerifying = false;

  @override
  void initState() {
    super.initState();
    _shopNameController.text = widget.onboardingData.shopName ?? '';
    _shopAddressController.text = widget.onboardingData.shopAddress ?? '';
    _phoneNumberController.text = widget.onboardingData.phoneNumber ?? '';
    _instagramIdController.text = widget.onboardingData.instagramId ?? '';
  }

  @override
  void didUpdateWidget(covariant ShopDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onboardingData.shopName != oldWidget.onboardingData.shopName) {
      _shopNameController.text = widget.onboardingData.shopName ?? '';
    }
    if (widget.onboardingData.shopAddress !=
        oldWidget.onboardingData.shopAddress) {
      _shopAddressController.text = widget.onboardingData.shopAddress ?? '';
    }
    if (widget.onboardingData.phoneNumber !=
        oldWidget.onboardingData.phoneNumber) {
      _phoneNumberController.text = widget.onboardingData.phoneNumber ?? '';
    }
    if (widget.onboardingData.instagramId !=
        oldWidget.onboardingData.instagramId) {
      _instagramIdController.text = widget.onboardingData.instagramId ?? '';
    }
  }

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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _shopNameController,
                    onChanged: (value) {
                      widget.onDataChanged(OnboardingData(
                        shopName: value,
                        shopAddress: widget.onboardingData.shopAddress,
                        phoneNumber: widget.onboardingData.phoneNumber,
                        instagramId: widget.onboardingData.instagramId,
                        logoFile: widget.onboardingData.logoFile,
                        userCategories: widget.onboardingData.userCategories,
                        userCollections: widget.onboardingData.userCollections,
                        selectedTheme: widget.onboardingData.selectedTheme,
                        productTypes: widget.onboardingData.productTypes,
                      ));
                    },
                    decoration: const InputDecoration(labelText: 'Shop Name'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shopAddressController,
                    onChanged: (value) {
                      widget.onDataChanged(OnboardingData(
                        shopName: widget.onboardingData.shopName,
                        shopAddress: value,
                        phoneNumber: widget.onboardingData.phoneNumber,
                        instagramId: widget.onboardingData.instagramId,
                        logoFile: widget.onboardingData.logoFile,
                        userCategories: widget.onboardingData.userCategories,
                        userCollections: widget.onboardingData.userCollections,
                        selectedTheme: widget.onboardingData.selectedTheme,
                        productTypes: widget.onboardingData.productTypes,
                      ));
                    },
                    decoration:
                        const InputDecoration(labelText: 'Shop Address'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneNumberController,
                    onChanged: (value) {
                      setState(() {
                        widget.onDataChanged(OnboardingData(
                          shopName: widget.onboardingData.shopName,
                          shopAddress: widget.onboardingData.shopAddress,
                          phoneNumber: value,
                          instagramId: widget.onboardingData.instagramId,
                          logoFile: widget.onboardingData.logoFile,
                          userCategories: widget.onboardingData.userCategories,
                          userCollections:
                              widget.onboardingData.userCollections,
                          selectedTheme: widget.onboardingData.selectedTheme,
                          productTypes: widget.onboardingData.productTypes,
                        ));
                        _isPhoneVerified = false;
                      });
                    },
                    onFieldSubmitted: (_) {
                      _startPhoneVerification();
                    },
                    decoration:
                        const InputDecoration(labelText: 'Phone Number'),
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
                      if (_isPhoneVerifying) const SizedBox(width: 12),
                      if (_isPhoneVerifying)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // const SizedBox(height: 16),
                  // DropdownButtonFormField<String>(
                  //   value: _selectedProductType,
                  //   decoration: const InputDecoration(labelText: 'Products You Sell'),
                  //   items: _productTypes.map((String value) {
                  //     return DropdownMenuItem<String>(
                  //       value: value,
                  //       child: Text(value),
                  //     );
                  //   }).toList(),
                  //   onChanged: (newValue) {
                  //     setState(() {
                  //       _selectedProductType = newValue;
                  //     });
                  //   },
                  // ),
                  TextFormField(
                    controller: _instagramIdController,
                    onChanged: (value) {
                      widget.onDataChanged(OnboardingData(
                        shopName: widget.onboardingData.shopName,
                        shopAddress: widget.onboardingData.shopAddress,
                        phoneNumber: widget.onboardingData.phoneNumber,
                        instagramId: value,
                        logoFile: widget.onboardingData.logoFile,
                        userCategories: widget.onboardingData.userCategories,
                        userCollections: widget.onboardingData.userCollections,
                        selectedTheme: widget.onboardingData.selectedTheme,
                        productTypes: widget.onboardingData.productTypes,
                      ));
                    },
                    decoration:
                        const InputDecoration(labelText: 'Instagram ID'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 24),
                  if (widget.onboardingData.logoFile != null)
                    Image.file(
                      widget.onboardingData.logoFile!,
                      height: 100,
                    ),
                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add Logo'),
                  ),
                ],
              ),
            ),
          ),
          if (_isPhoneVerifying)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
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
      print('[ShopDetails] Starting phone verification for $phone');
      final taken = await _firestoreService.isPhoneNumberTaken(phone);
      if (taken) {
        print('[ShopDetails] Phone number already in use');
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
              print(
                  '[ShopDetails] verificationCompleted: reauthenticating user ${user.uid}');
              await user.reauthenticateWithCredential(credential);
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
            print('[ShopDetails] Error in verificationCompleted: $e');
            if (e is FirebaseAuthException &&
                e.code == 'provider-already-linked') {
              // Phone is already linked to this user; treat as verified.
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Phone number is already verified')),
                );
              }
              setState(() {
                _isPhoneVerified = true;
              });
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Failed to link phone number to account')),
                );
              }
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('[ShopDetails] verificationFailed: ${e.code} - ${e.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Verification failed: ${e.message ?? 'Unknown error'}')),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          print('[ShopDetails] codeSent, verificationId: $verificationId');
          setState(() {
            _verificationId = verificationId;
          });
          _showOtpDialog();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print(
              '[ShopDetails] codeAutoRetrievalTimeout, verificationId: $verificationId');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      print('[ShopDetails] Error starting phone verification: $e');
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
              onPressed: _isOtpVerifying
                  ? null
                  : () async {
                      final smsCode = controller.text.trim();
                      if (_verificationId == null || smsCode.isEmpty) {
                        print(
                            '[ShopDetails] OTP Verify tapped but verificationId or smsCode is empty. verificationId=$_verificationId, smsCodeLength=${smsCode.length}');
                        return;
                      }

                      if (mounted) {
                        setState(() {
                          _isOtpVerifying = true;
                        });
                      }

                      try {
                        print('[ShopDetails] Verifying OTP...');
                        final credential = PhoneAuthProvider.credential(
                          verificationId: _verificationId!,
                          smsCode: smsCode,
                        );
                        final user = _auth.currentUser;
                        if (user != null) {
                          await user.linkWithCredential(credential);
                          print(
                              '[ShopDetails] OTP verified and linked for user ${user.uid}');
                        } else {
                          print(
                              '[ShopDetails] No current user while verifying OTP');
                        }
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Phone number verified')),
                          );
                        }
                        if (mounted) {
                          setState(() {
                            _isPhoneVerified = true;
                          });
                        }
                      } catch (e) {
                        print('[ShopDetails] Error verifying OTP: $e');
                        if (e is FirebaseAuthException &&
                            e.code == 'provider-already-linked') {
                          // Phone already linked to this user; treat as verified.
                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Phone number is already verified')),
                            );
                          }
                          if (mounted) {
                            setState(() {
                              _isPhoneVerified = true;
                            });
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invalid OTP')),
                            );
                          }
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isOtpVerifying = false;
                          });
                        }
                      }
                    },
              child: _isOtpVerifying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      widget.onDataChanged(OnboardingData(
        shopName: widget.onboardingData.shopName,
        shopAddress: widget.onboardingData.shopAddress,
        phoneNumber: widget.onboardingData.phoneNumber,
        instagramId: widget.onboardingData.instagramId,
        logoFile: File(pickedFile.path),
        userCategories: widget.onboardingData.userCategories,
        userCollections: widget.onboardingData.userCollections,
        selectedTheme: widget.onboardingData.selectedTheme,
        productTypes: widget.onboardingData.productTypes,
      ));
    }
  }
}
