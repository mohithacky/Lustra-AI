import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/services/gemini_service.dart';

class TryOnScreen extends StatefulWidget {
  final String shopId;
  final String productId;

  const TryOnScreen({Key? key, required this.shopId, required this.productId})
      : super(key: key);

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  final GeminiService _geminiService = GeminiService();

  Map<String, dynamic>? _product;
  bool _isLoadingProduct = true;
  String? _loadError;

  Uint8List? _customerImageBytes;
  bool _isGenerating = false;
  String? _generatedImageBase64;

  @override
  void initState() {
    super.initState();
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    setState(() {
      _isLoadingProduct = true;
      _loadError = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.shopId)
          .collection('products')
          .doc(widget.productId)
          .get();

      if (!doc.exists) {
        setState(() {
          _loadError = 'Product not found.';
          _isLoadingProduct = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      setState(() {
        _product = data;
        _isLoadingProduct = false;
      });
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load product: $e';
        _isLoadingProduct = false;
      });
    }
  }

  Future<void> _pickCustomerImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    setState(() {
      _customerImageBytes = bytes;
      _generatedImageBase64 = null;
    });
  }

  Future<void> _showImageSourcePicker() async {
    if (_isGenerating) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source != null && mounted) {
      await _pickCustomerImage(source);
    }
  }

  String? _resolveProductImageUrl(Map<String, dynamic> product) {
    final primary = product['imageUrl'];
    if (primary != null && primary.toString().isNotEmpty) {
      return primary.toString();
    }

    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
    }

    final legacy = product['imagePath'];
    if (legacy != null && legacy.toString().isNotEmpty) {
      return legacy.toString();
    }

    return null;
  }

  Future<void> _generateTryOn() async {
    if (_product == null) return;
    if (_customerImageBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a customer photo first.')),
      );
      return;
    }

    final productImageUrl = _resolveProductImageUrl(_product!);
    if (productImageUrl == null || productImageUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('This product does not have a primary image for try-on.'),
        ),
      );
      return;
    }

    final customerBase64 = base64Encode(_customerImageBytes!);

    final productName = (_product!['name'] ?? '').toString();
    final category = (_product!['category'] ?? '').toString();
    final subcategory = (_product!['subcategory'] ?? '').toString();

    setState(() {
      _isGenerating = true;
      _generatedImageBase64 = null;
    });

    try {
      final generated = await _geminiService.generateTryOnImage(
        productImageUrl: productImageUrl,
        customerImageBase64: customerBase64,
        productName: productName.isNotEmpty ? productName : null,
        category: category.isNotEmpty ? category : null,
        subcategory: subcategory.isNotEmpty ? subcategory : null,
      );

      if (!mounted) return;
      setState(() {
        _generatedImageBase64 = generated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate try-on image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Virtual Try-On')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final product = _product!;
    final productName = (product['name'] ?? '').toString();
    final productImageUrl = _resolveProductImageUrl(product);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          productName.isNotEmpty ? productName : 'Virtual Try-On',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (productImageUrl != null && productImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  productImageUrl,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              productName.isNotEmpty ? productName : 'Jewellery product',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Shop: ${widget.shopId}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload customer photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_customerImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _customerImageBytes!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'No photo selected',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _showImageSourcePicker,
                icon: const Icon(Icons.photo),
                label: const Text('Choose Photo'),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isGenerating || _customerImageBytes == null
                    ? null
                    : _generateTryOn,
                child: _isGenerating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Generate Try-On'),
              ),
            ),
            const SizedBox(height: 24),
            if (_generatedImageBase64 != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Result',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      base64Decode(_generatedImageBase64!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
