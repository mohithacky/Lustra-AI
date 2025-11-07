import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

class ShopDetailsScreen extends StatefulWidget {
  static const String routeName = '/shop-details';

  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const ShopDetailsScreen({
    Key? key,
    required this.onboardingData,
    required this.onDataChanged,
  })
      : super(key: key);

  @override
  _ShopDetailsScreenState createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _instagramIdController = TextEditingController();

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
    if (widget.onboardingData.shopAddress != oldWidget.onboardingData.shopAddress) {
      _shopAddressController.text = widget.onboardingData.shopAddress ?? '';
    }
    if (widget.onboardingData.phoneNumber != oldWidget.onboardingData.phoneNumber) {
      _phoneNumberController.text = widget.onboardingData.phoneNumber ?? '';
    }
    if (widget.onboardingData.instagramId != oldWidget.onboardingData.instagramId) {
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
      body: Padding(
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
                  ));
                },
                decoration: const InputDecoration(labelText: 'Shop Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                onChanged: (value) {
                  widget.onDataChanged(OnboardingData(
                    shopName: widget.onboardingData.shopName,
                    shopAddress: widget.onboardingData.shopAddress,
                    phoneNumber: value,
                    instagramId: widget.onboardingData.instagramId,
                    logoFile: widget.onboardingData.logoFile,
                    userCategories: widget.onboardingData.userCategories,
                    userCollections: widget.onboardingData.userCollections,
                    selectedTheme: widget.onboardingData.selectedTheme,
                  ));
                },
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
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
                  ));
                },
                decoration: const InputDecoration(labelText: 'Instagram ID'),
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
      ));
    }
  }
}
