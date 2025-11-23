import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);
const Color kOffWhite = Color(0xFFF8F7F4);

class OurShopScreen extends StatefulWidget {
  final String userId;

  const OurShopScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _OurShopScreenState createState() => _OurShopScreenState();
}

class _OurShopScreenState extends State<OurShopScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _photoUrls = [];
  final List<File> _newImages = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _fetchOurShopData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchOurShopData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final description = data['ourShopDescription'] as String?;
        final photos = (data['ourShopPhotos'] as List<dynamic>?) ?? [];

        _descriptionController.text = description ?? '';
        _photoUrls
          ..clear()
          ..addAll(photos.cast<String>());
      }
    } catch (e) {
      debugPrint('Error loading Our Shop data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    if (kIsWeb) return; // editing disabled on web

    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newImages.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _saveOurShopData() async {
    if (kIsWeb) return; // safety guard
    setState(() {
      _isSaving = true;
    });

    try {
      // Upload any newly added images
      for (final file in _newImages) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'users/${widget.userId}/our_shop/${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}');
        final uploadTask = await storageRef.putFile(file);
        final url = await uploadTask.ref.getDownloadURL();
        _photoUrls.add(url);
      }

      _newImages.clear();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(
        {
          'ourShopDescription': _descriptionController.text.trim(),
          'ourShopPhotos': _photoUrls,
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Our Shop details updated successfully.')),
      );
    } catch (e) {
      debugPrint('Error saving Our Shop data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save Our Shop details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bool isAdminApp = !kIsWeb; // only mobile app can edit

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Our Shop',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kBlack,
          ),
        ),
        actions: [
          if (isAdminApp)
            IconButton(
              icon: Icon(
                _isEditing ? Icons.check : Icons.edit,
                color: kBlack,
              ),
              onPressed: _isEditing
                  ? () {
                      if (!_isSaving) {
                        _saveOurShopData();
                      }
                    }
                  : () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
            ),
        ],
      ),
      floatingActionButton: isAdminApp && _isEditing
          ? FloatingActionButton(
              backgroundColor: kGold,
              onPressed: _pickImage,
              child: const Icon(Icons.add_a_photo, color: Colors.white),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Our Shop',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isAdminApp && _isEditing)
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText:
                            'Describe your shop, history, and what makes it special...',
                        hintStyle: GoogleFonts.lato(
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  else
                    Text(
                      _descriptionController.text.isNotEmpty
                          ? _descriptionController.text
                          : 'Shop description is not added yet.',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Shop Photos',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_photoUrls.isEmpty && _newImages.isEmpty)
                    Text(
                      isAdminApp
                          ? 'No photos added yet. Tap the camera button to add shop photos.'
                          : 'No shop photos available yet.',
                      style: GoogleFonts.lato(color: Colors.grey),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _photoUrls.length + _newImages.length,
                      itemBuilder: (context, index) {
                        final bool isExisting = index < _photoUrls.length;
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: isExisting
                                    ? Image.network(
                                        _photoUrls[index],
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        _newImages[index - _photoUrls.length],
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            if (isAdminApp && _isEditing)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isExisting) {
                                        _photoUrls.removeAt(index);
                                      } else {
                                        _newImages.removeAt(
                                            index - _photoUrls.length);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
