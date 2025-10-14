import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/gemini_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

class AdShootGenerationScreen extends StatefulWidget {
  final Template template;

  const AdShootGenerationScreen({Key? key, required this.template}) : super(key: key);

  @override
  _AdShootGenerationScreenState createState() => _AdShootGenerationScreenState();
}

class _AdShootGenerationScreenState extends State<AdShootGenerationScreen> {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();
  final List<TextEditingController> _textControllers = [];
  final List<TextEditingController> _dynamicTextControllers = [];
  final List<String> _dynamicAdTextHints = [];
  Map<String, dynamic>? _shopDetails;
  String? _generatedImage;
  bool _isLoading = false;
  File? _userImage;
  List<String> _selectedDiscounts = ['Gold'];
  final List<String> _discountOptions = ['Gold', 'Silver', 'Diamond'];

  @override
  void initState() {
    super.initState();
    _fetchShopDetails();
    for (var _ in widget.template.adTextHints) {
      _textControllers.add(TextEditingController());
    }
  }

  Future<void> _fetchShopDetails() async {
    final details = await _firestoreService.getUserDetails();
    if (mounted) {
      setState(() {
        _shopDetails = details;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _textControllers) {
      controller.dispose();
    }
    for (var controller in _dynamicTextControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _userImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _generateImage() async {
    if (_userImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload an image to generate a poster.')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _generatedImage = null;
    });

    try {
      String modifiedPrompt = widget.template.prompt;
      final Map<String, dynamic> replacements = {};

      // 1. Gather details from Firestore
      if (_shopDetails != null) {
        _shopDetails!.forEach((key, value) {
          replacements[key] = value?.toString() ?? '';
        });
      }

      // 2. Gather details from dropdowns
      if (widget.template.hasMetalTypeDropdown) {
        replacements['Discounts on'] = _selectedDiscounts.join(', ');
      }

      // 3. Gather details from dynamic text fields
      if (widget.template.hasDynamicTextFields) {
        final List<String> features = [];
        for (int i = 0; i < widget.template.adTextHints.length; i++) {
          String value = _textControllers[i].text;
          if (value.trim().isNotEmpty) {
            features.add(value);
          }
        }
        for (var controller in _dynamicTextControllers) {
          String value = controller.text;
          if (value.trim().isNotEmpty) {
            features.add(value);
          }
        }
        replacements['features'] = features;
      } else {
        // Fallback for templates where the toggle is off but they have hints
        for (int i = 0; i < widget.template.adTextHints.length; i++) {
          String hint = widget.template.adTextHints[i];
          String value = _textControllers[i].text;
          replacements[hint] = value;
        }
      }

      // Perform all replacements
      replacements.forEach((key, value) {
        if (value is String) {
          modifiedPrompt = modifiedPrompt.replaceAll('{$key}', value);
        }
      });

      // Append a strong instruction for all features to be included
      if (widget.template.hasDynamicTextFields && replacements.containsKey('features')) {
        final featuresList = replacements['features'] as List<String>;
        if (featuresList.isNotEmpty) {
          final featuresString = featuresList.map((f) => '"$f"').join(', ');
          modifiedPrompt +=
              '\n\nImportant: The generated image must visually include and represent all of the following features: $featuresString.';
        }
      }

      print('--- Complete Replacements Map ---');
      print(jsonEncode(replacements));
      print('---------------------------------');

      print('--- Modified Prompt Start ---');
      const int chunkSize = 800;
      for (int i = 0; i < modifiedPrompt.length; i += chunkSize) {
        int end = (i + chunkSize < modifiedPrompt.length) ? i + chunkSize : modifiedPrompt.length;
        print(modifiedPrompt.substring(i, end));
      }
      print('--- Modified Prompt End ---');

      final generatedImage = await _geminiService.generateImageWithUpload(modifiedPrompt, _userImage!);

      setState(() {
        _generatedImage = generatedImage;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating image: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveImage() async {
    if (_generatedImage == null) return;

    var status = await Permission.photos.request();
    if (status.isGranted) {
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(base64Decode(_generatedImage!)),
        quality: 100,
        name: "lustra_ai_image_${DateTime.now().millisecondsSinceEpoch}",
      );
      if (mounted && (result['isSuccess'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery!')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied.')),
        );
      }
    }
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/generated_image.png').create();
      await file.writeAsBytes(base64Decode(_generatedImage!));

      final xFile = XFile(file.path);

      await Share.shareXFiles([xFile], text: 'Created with Lustra AI!');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.title),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_generatedImage != null)
              Column(
                children: [
                  Image.memory(base64Decode(_generatedImage!)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share, color: AppTheme.accentColor),
                        onPressed: _shareImage,
                        tooltip: 'Share',
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: AppTheme.accentColor),
                        onPressed: _saveImage,
                        tooltip: 'Download',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _generatedImage = null;
                        for (var controller in _textControllers) {
                          controller.clear();
                        }
                        for (var controller in _dynamicTextControllers) {
                          controller.clear();
                        }
                        _dynamicTextControllers.clear();
                        _dynamicAdTextHints.clear();
                        _userImage = null;
                      });
                    },
                    child: const Text('Start Over'),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_shopDetails != null) _buildShopDetailsCard(),
                  const SizedBox(height: 20),
                  _buildImageUploader(),
                  const SizedBox(height: 20),
                  if (widget.template.hasMetalTypeDropdown) _buildDiscountMultiSelect(),
                  if (widget.template.hasDynamicTextFields)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text('Enter Ad Texts:', style: Theme.of(context).textTheme.titleLarge),
                            if (widget.template.hasDynamicTextFields)
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: AppTheme.accentColor),
                                onPressed: _showAddFeatureDialog,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...widget.template.adTextHints.asMap().entries.map((entry) {
                          int index = entry.key;
                          String hint = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TextFormField(
                              controller: _textControllers[index],
                              decoration: InputDecoration(
                                hintText: hint,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          );
                        }).toList(),
                        ..._dynamicAdTextHints.asMap().entries.map((entry) {
                          int index = entry.key;
                          String hint = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: TextFormField(
                              controller: _dynamicTextControllers[index],
                              decoration: InputDecoration(
                                hintText: hint,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _generateImage,
                            child: const Text('Apply Template'),
                          ),
                        ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopDetailsCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Shop Details', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.accentColor),
                  onPressed: () {
                    _showEditShopDetailsDialog();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Name: ${_shopDetails!['shopName'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Address: ${_shopDetails!['shopAddress'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text('Phone: ${_shopDetails!['phoneNumber'] ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  void _showEditShopDetailsDialog() {
    if (_shopDetails == null) return;

    final nameController = TextEditingController(text: _shopDetails!['shopName']);
    final addressController = TextEditingController(text: _shopDetails!['shopAddress']);
    final phoneController = TextEditingController(text: _shopDetails!['phoneNumber']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Details for this Poster'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Shop Name'),
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Shop Address'),
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _shopDetails = {
                    'shopName': nameController.text,
                    'shopAddress': addressController.text,
                    'phoneNumber': phoneController.text,
                  };
                });
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageUploader() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _userImage != null
            ? Image.file(_userImage!, fit: BoxFit.cover)
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 50),
                    SizedBox(height: 8),
                    Text('Upload Your Image'),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDiscountMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Discounts on', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.accentColor),
              onPressed: _showDiscountMultiSelectDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: _selectedDiscounts.map((item) => Chip(label: Text(item))).toList(),
        ),
      ],
    );
  }

  void _showDiscountMultiSelectDialog() {
    final tempSelected = List<String>.from(_selectedDiscounts);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Discount Items'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8.0,
                  children: _discountOptions.map((item) {
                    final isSelected = tempSelected.contains(item);
                    return FilterChip(
                      label: Text(item),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            tempSelected.add(item);
                          } else {
                            tempSelected.remove(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedDiscounts = tempSelected;
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddFeatureDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add a New Feature'),
          content: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter feature name (e.g., Offer)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _dynamicAdTextHints.add(controller.text);
                    _dynamicTextControllers.add(TextEditingController());
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
