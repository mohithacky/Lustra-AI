import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/home_screen.dart';
import 'package:lustra_ai/services/firestore_service.dart';

class ShopDetailsScreen extends StatefulWidget {
  static const String routeName = '/shop-details';

  const ShopDetailsScreen({Key? key}) : super(key: key);

  @override
  _ShopDetailsScreenState createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<ShopDetailsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  File? _logoFile;
  bool _isLoading = false;
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String? _selectedProductType = 'Gold';
  final List<String> _productTypes = ['Gold', 'Diamond', 'Both'];

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _phoneNumberController.dispose();
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
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProductType,
                decoration: const InputDecoration(labelText: 'Products You Sell'),
                items: _productTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedProductType = newValue;
                  });
                },
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
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _isLoading = true;
                      });
                      try {
                        String? logoUrl;
                        if (_logoFile != null) {
                          logoUrl = await _firestoreService.uploadShopLogo(_logoFile!);
                        }
                        await _firestoreService.addShopDetails(
                          _shopNameController.text,
                          _shopAddressController.text,
                          _phoneNumberController.text,
                          logoUrl,
                          _selectedProductType,
                        );
                        if (mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                          );
                        }
                      } catch (e) {
                        // Handle error
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                          });
                        }
                      }
                    }
                  },
                  child: const Text('Submit'),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: const Text('Skip'),
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
      setState(() {
        _logoFile = File(pickedFile.path);
      });
    }
  }
}
