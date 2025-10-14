import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/models/jewellery.dart';

class AddJewelleryScreen extends StatefulWidget {
  const AddJewelleryScreen({Key? key}) : super(key: key);

  @override
  _AddJewelleryScreenState createState() => _AddJewelleryScreenState();
}

class _AddJewelleryScreenState extends State<AddJewelleryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _typeController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountController = TextEditingController();
  bool _isBestseller = false;
  File? _image;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  void _saveJewellery() {
    if (_formKey.currentState!.validate()) {
      if (_image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image.')),
        );
        return;
      }

      final newJewellery = Jewellery(
        name: _nameController.text,
        weight: double.parse(_weightController.text),
        imagePath: _image!.path,
        type: _typeController.text,
        price: _priceController.text,
        originalPrice: _originalPriceController.text.isNotEmpty
            ? _originalPriceController.text
            : null,
        discount: _discountController.text.isNotEmpty
            ? _discountController.text
            : null,
        isBestseller: _isBestseller,
      );

      Navigator.of(context).pop(newJewellery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Jewellery'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: _image != null
                      ? Image.file(_image!, fit: BoxFit.cover)
                      : const Icon(Icons.add_a_photo,
                          size: 50, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Weight (grams)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a weight';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                    labelText: 'Type (e.g. Necklace, Ring, Bracelet)'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _originalPriceController,
                decoration: const InputDecoration(
                  labelText: 'Original Price (₹) - Optional',
                  hintText: 'Leave blank if no discount',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _discountController,
                decoration: const InputDecoration(
                  labelText: 'Discount Text - Optional',
                  hintText: 'e.g. 7% off on making charges',
                ),
              ),
              const SizedBox(height: 16.0),
              SwitchListTile(
                title: const Text('Bestseller'),
                value: _isBestseller,
                onChanged: (bool value) {
                  setState(() {
                    _isBestseller = value;
                  });
                },
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _saveJewellery,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
