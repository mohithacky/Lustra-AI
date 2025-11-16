import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../services/firestore_service.dart';

// Import shared color constants
const Color kOffWhite = Color(0xFFF8F7F4);
const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);

class AddProductScreen extends StatefulWidget {
  final String categoryName;
  final String userId;

  const AddProductScreen(
      {Key? key, required this.categoryName, required this.userId})
      : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountController = TextEditingController();
  final _weightController = TextEditingController();

  // TODO: Add image picker logic
  File? _imageFile;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isBestseller = false;
  bool _isTrending = false;
  bool _isLoading = false;
  String _selectedGender = 'Her';
  String? _selectedCollection;
  List<String> _collections = [];

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    final collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    final collections = collectionsSnapshot['collections'];
    setState(() {
      _collections = collections.keys.toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOffWhite,
      appBar: AppBar(
        backgroundColor: kOffWhite,
        elevation: 0,
        title: Text(
          'Add New Product',
          style: GoogleFonts.lora(color: kBlack, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _imageFile == null
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('Select Image'),
                      onPressed: _pickImage,
                    )
                  : Image.file(_imageFile!),
              const SizedBox(height: 24),
              const SizedBox(height: 24),
              _buildTextFormField(_nameController, 'Product Name'),
              const SizedBox(height: 16),
              _buildCollectionDropdown(),
              const SizedBox(height: 16),
              _buildTextFormField(_priceController, 'Price',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextFormField(
                  _originalPriceController, 'Original Price (Optional)',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildTextFormField(
                  _discountController, 'Discount Tag (e.g., 20% OFF)'),
              const SizedBox(height: 16),
              _buildTextFormField(_weightController, 'Weight (grams)',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _buildSwitchTile('Bestseller', _isBestseller, (value) {
                setState(() {
                  _isBestseller = value;
                });
              }),
              _buildSwitchTile('Trending', _isTrending, (value) {
                setState(() {
                  _isTrending = value;
                });
              }),
              const SizedBox(height: 24),
              Text('For',
                  style: GoogleFonts.lato(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Him'),
                    selected: _selectedGender == 'Him',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedGender = 'Him';
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Her'),
                    selected: _selectedGender == 'Her',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedGender = 'Her';
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label,
      {TextInputType? keyboardType}) {
    return TextFormField(
      style: TextStyle(
        color: Colors.black,
      ),
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.lato(color: kBlack.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBlack.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBlack.withOpacity(0.1)),
        ),
      ),
      validator: (value) {
        if (label.contains('Optional')) return null;
        if (value == null || value.isEmpty) {
          return 'Please enter a $label';
        }
        return null;
      },
    );
  }

  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: GoogleFonts.lato()),
      value: value,
      onChanged: onChanged,
      activeColor: kGold,
    );
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Widget _buildCollectionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCollection,
      hint: const Text(
        'Select Collection',
        style: TextStyle(color: Colors.black),
      ),
      items: _collections.map((String collection) {
        return DropdownMenuItem<String>(
          value: collection,
          child: Text(collection),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedCollection = newValue;
        });
      },
      validator: (value) => value == null ? 'Please select a collection' : null,
      decoration: InputDecoration(
        labelText: 'Collection',
        labelStyle: GoogleFonts.lato(color: kBlack.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBlack.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kBlack.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _saveProduct,
      style: ElevatedButton.styleFrom(
        backgroundColor: kGold,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            )
          : Text(
              'Save Product',
              style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white),
            ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final imageUrl = await _firestoreService.uploadProductImage(
          _imageFile!, _nameController.text);

      final productData = {
        'name': _nameController.text,
        'collection': _selectedCollection,
        'price': _priceController.text,
        'originalPrice': _originalPriceController.text,
        'discount': _discountController.text,
        'isBestseller': _isBestseller,
        'weight': _weightController.text,
        'isTrending': _isTrending,
        'imagePath': imageUrl,
        'gender': _selectedGender,
        'createdAt': Timestamp.now(),
      };

      await _firestoreService.addProduct(widget.categoryName, productData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add product: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
