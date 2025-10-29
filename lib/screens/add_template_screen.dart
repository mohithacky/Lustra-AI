import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';

class AddTemplateScreen extends StatefulWidget {
  final Template? template;
  final String templateType;

  const AddTemplateScreen({Key? key, this.template, required this.templateType})
      : super(key: key);

  @override
  _AddTemplateScreenState createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends State<AddTemplateScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  File? _image;
  final _nameController = TextEditingController();
  final _promptController = TextEditingController();
  final _promptForSinglePhoneNumberController = TextEditingController();
  final _promptForMultiplePhoneNumbersController = TextEditingController();
  final _jewelleryTypeController = TextEditingController();
  final _numberOfJewelleriesController = TextEditingController();
  bool _isLoading = false;
  String _selectedGender = 'both';
  // Collection selection state
  final List<String> _parentCollections = ['Festive', 'Luxury', 'Minimal', 'Trending'];
  List<String> _selectedParentCollections = [];
  List<Map<String, dynamic>> _subCollections = [];
  List<String> _selectedSubCollections = [];
  List<String> _selectedCollections = [];
  List<String> _adTextHints = [];
  bool _hasMetalTypeDropdown = false;
  bool _hasDynamicTextFields = false;
  bool _addLinesList = false;
  final _linesListController = TextEditingController();
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _nameController.text = widget.template!.title;
      _promptController.text = widget.template!.prompt;
      _promptForSinglePhoneNumberController.text = widget.template!.promptForSinglePhoneNumber;
      _promptForMultiplePhoneNumbersController.text = widget.template!.promptForMultiplePhoneNumbers;
      _jewelleryTypeController.text = widget.template!.jewelleryType;
      _numberOfJewelleriesController.text =
          widget.template!.numberOfJewelleries.toString();
      _selectedGender = widget.template!.gender;
      _selectedCollections = List<String>.from(widget.template!.collection);
      _adTextHints = List<String>.from(widget.template!.adTextHints);
      _hasMetalTypeDropdown = widget.template!.hasMetalTypeDropdown;
      _hasDynamicTextFields = widget.template!.hasDynamicTextFields;
      if (widget.template!.linesList.isNotEmpty) {
        _addLinesList = true;
        _linesListController.text = widget.template!.linesList.join('|||');
      }
    }
    if (widget.templateType == 'AdShoot') {
      // If editing, pre-select collections
      if (widget.template != null) {
        _selectedCollections = List<String>.from(widget.template!.collection);
        _selectedSubCollections = List<String>.from(widget.template!.collection);
        // We don't know the parent collections here, so the UI might not be perfectly in sync
        // A better approach would be to store parent collections in the template data
      }
    }
  }

  void _onParentCollectionSelected(String collection, bool selected) {
    setState(() {
      if (selected) {
        _selectedParentCollections.add(collection);
      } else {
        _selectedParentCollections.remove(collection);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _promptController.dispose();
    _promptForSinglePhoneNumberController.dispose();
    _promptForMultiplePhoneNumbersController.dispose();
    _jewelleryTypeController.dispose();
    _numberOfJewelleriesController.dispose();
    _linesListController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveTemplate() async {
    if (_nameController.text.isEmpty ||
        _promptController.text.isEmpty ||
        (widget.template == null && _image == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String successMessage;
      final numberOfJewelleries =
          int.tryParse(_numberOfJewelleriesController.text) ?? 1;
      final linesList = _addLinesList
          ? _linesListController.text.split('|||').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];

      // For AdShoot, the 'collection' field stores the sub-collections
      if (widget.templateType == 'AdShoot') {
        _selectedCollections = _selectedSubCollections;
      }

      if (widget.template != null) {
        // Update existing template
        final updatedTemplate = Template(
          id: widget.template!.id,
          title: _nameController.text,
          prompt: _promptController.text,
          promptForSinglePhoneNumber: _promptForSinglePhoneNumberController.text,
          promptForMultiplePhoneNumbers: _promptForMultiplePhoneNumbersController.text,
          imageUrl: widget.template!.imageUrl, // Image URL is not changed on update for now
          author: widget.template!.author,
          likes: widget.template!.likes,
          likedBy: widget.template!.likedBy,
          useCount: widget.template!.useCount,
          jewelleryType: _jewelleryTypeController.text,
          createdAt: widget.template!.createdAt,
          numberOfJewelleries: numberOfJewelleries,
          templateType: widget.templateType,
          gender: _selectedGender,
          collection: _selectedCollections,
          adTextHints: _adTextHints,
          hasMetalTypeDropdown: _hasMetalTypeDropdown,
          hasDynamicTextFields: _hasDynamicTextFields,
          linesList: linesList,
        );
        await _firestoreService.updateTemplate(updatedTemplate, _image);
        successMessage = 'Template updated successfully!';
      } else {
        // Add new template
        final newTemplate = Template(
          id: '', // ID will be generated by Firestore
          title: _nameController.text,
          prompt: _promptController.text,
          promptForSinglePhoneNumber: _promptForSinglePhoneNumberController.text,
          promptForMultiplePhoneNumbers: _promptForMultiplePhoneNumbersController.text,
          imageUrl: '', // Will be set after upload
          author: 'admin@lustra.ai', // Or get current user
          likes: 0,
          jewelleryType: _jewelleryTypeController.text,
          numberOfJewelleries: numberOfJewelleries,
          templateType: widget.templateType,
          gender: _selectedGender,
          collection: _selectedCollections,
          adTextHints: _adTextHints,
          hasMetalTypeDropdown: _hasMetalTypeDropdown,
          hasDynamicTextFields: _hasDynamicTextFields,
          linesList: linesList,
        );
        await _firestoreService.addTemplate(newTemplate, _image!);
        successMessage = 'Template added successfully!';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddHintDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Hint Text'),
          content: TextFormField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter hint for the text field'),
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
                    _adTextHints.add(controller.text);
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

  @override
  Widget build(BuildContext context) {
    final isAdShoot = widget.templateType == 'AdShoot';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template == null ? 'Add Template' : 'Edit Template'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveTemplate,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Template Name'),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'e.g., Diwali Special'),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Template Image'),
                  _buildImageUploader(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Prompt'),
                  TextFormField(
                    controller: _promptController,
                    decoration: const InputDecoration(
                        hintText: 'e.g., A gold necklace on a marble surface...'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Prompt for Single Phone Number'),
                  TextFormField(
                    controller: _promptForSinglePhoneNumberController,
                    decoration: const InputDecoration(
                        hintText: 'Prompt when one phone number is present...'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Prompt for Multiple Phone Numbers'),
                  TextFormField(
                    controller: _promptForMultiplePhoneNumbersController,
                    decoration: const InputDecoration(
                        hintText: 'Prompt when multiple phone numbers are present...'),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  if (isAdShoot)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Ad Text Hints'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _adTextHints.map((hint) {
                            return Chip(
                              label: Text(hint),
                              onDeleted: () {
                                setState(() {
                                  _adTextHints.remove(hint);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.add_circle, color: AppTheme.accentColor),
                            onPressed: _showAddHintDialog,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Add "Discounts on" Dropdown'),
                            Switch(
                              value: _hasMetalTypeDropdown,
                              onChanged: (value) {
                                setState(() {
                                  _hasMetalTypeDropdown = value;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_hasMetalTypeDropdown)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Use the placeholder {metalType} in your prompt.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Enable Dynamic Text Fields'),
                            Switch(
                              value: _hasDynamicTextFields,
                              onChanged: (value) {
                                setState(() {
                                  _hasDynamicTextFields = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Add lines list'),
                            Switch(
                              value: _addLinesList,
                              onChanged: (value) {
                                setState(() {
                                  _addLinesList = value;
                                });
                              },
                            ),
                          ],
                        ),
                        if (_addLinesList)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                            child: TextFormField(
                              controller: _linesListController,
                              decoration: const InputDecoration(
                                hintText: 'Enter lines separated by |||',
                              ),
                              maxLines: 3,
                            ),
                          ),
                        _buildSectionTitle('Collections'),
                        Wrap(
                          spacing: 8.0,
                          children: _parentCollections.map((collection) {
                            return ChoiceChip(
                              label: Text(collection),
                              selected: _selectedParentCollections.contains(collection),
                              onSelected: (selected) => _onParentCollectionSelected(collection, selected),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        _buildSectionTitle('Sub-Collections'),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _selectedParentCollections.isNotEmpty
                              ? _firestoreService.getAdShootSubCollections(_selectedParentCollections.last)
                              : Future.value([]),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('No sub-collections found for the selected parent collections.');
                            }
                            _subCollections = snapshot.data!;
                            return Wrap(
                              spacing: 8.0,
                              children: _subCollections.map((subCollection) {
                                final subCollectionName = subCollection['name'] as String;
                                return ChoiceChip(
                                  label: Text(subCollectionName),
                                  selected: _selectedSubCollections.contains(subCollectionName),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedSubCollections.add(subCollectionName);
                                      } else {
                                        _selectedSubCollections.remove(subCollectionName);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
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
        child: _image != null
            ? Image.file(_image!, fit: BoxFit.cover)
            : (widget.template?.imageUrl != null && widget.template!.imageUrl.isNotEmpty)
                ? Image.network(widget.template!.imageUrl, fit: BoxFit.cover)
                : const Center(child: Icon(Icons.add_a_photo, size: 50)),
      ),
    );
  }
}
