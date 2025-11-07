import 'dart:io';

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
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
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
}
