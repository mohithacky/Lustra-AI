import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lustra_ai/services/gemini_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/screens/jewellery_catalogue_screen.dart';

class EcommerceStudioGenerationScreen extends StatefulWidget {
  const EcommerceStudioGenerationScreen({Key? key}) : super(key: key);

  @override
  State<EcommerceStudioGenerationScreen> createState() =>
      _EcommerceStudioGenerationScreenState();
}

class _EcommerceStudioGenerationScreenState
    extends State<EcommerceStudioGenerationScreen> {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  File? _frontImage;
  File? _sideImage;
  File? _backImage;
  File? _extraImage;

  String? _frontResult;
  String? _sideResult;
  String? _backResult;
  String? _extraResult;

  bool get _hasAnyResult =>
      _frontResult != null ||
      _sideResult != null ||
      _backResult != null ||
      _extraResult != null;

  bool _isLoading = false;
  bool _isLoadingPrompts = true;
  String? _errorMessage;

  Map<String, String> _prompts = {
    'front': '',
    'side': '',
    'back': '',
    'extra': '',
  };

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    try {
      final loaded = await _firestoreService.getEcommerceStudioPrompts();
      if (!mounted) return;
      setState(() {
        _prompts = {
          'front': loaded['front'] ?? '',
          'side': loaded['side'] ?? '',
          'back': loaded['back'] ?? '',
          'extra': loaded['extra'] ?? '',
        };
        _isLoadingPrompts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPrompts = false;
        _errorMessage = 'Failed to load Ecommerce Studio prompts.';
      });
    }
  }

  Future<void> _pickImage(String key) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      final file = File(pickedFile.path);
      switch (key) {
        case 'front':
          _frontImage = file;
          break;
        case 'side':
          _sideImage = file;
          break;
        case 'back':
          _backImage = file;
          break;
        case 'extra':
          _extraImage = file;
          break;
      }
      _frontResult = null;
      _sideResult = null;
      _backResult = null;
      _extraResult = null;
    });
  }

  Future<void> _generate() async {
    final jobs = <_SectionJob>[];
    if (_frontImage != null) {
      jobs.add(_SectionJob('front', _frontImage!));
    }
    if (_sideImage != null) {
      jobs.add(_SectionJob('side', _sideImage!));
    }
    if (_backImage != null) {
      jobs.add(_SectionJob('back', _backImage!));
    }
    if (_extraImage != null) {
      jobs.add(_SectionJob('extra', _extraImage!));
    }

    if (jobs.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one image.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _frontResult = null;
      _sideResult = null;
      _backResult = null;
      _extraResult = null;
    });

    try {
      final userDoc = await _firestoreService.getUserStream().first;
      final userData = userDoc.data() as Map<String, dynamic>?;
      final currentCoins = userData?['coins'] ?? 0;
      const costPerImage = 5;
      final neededCoins = jobs.length * costPerImage;

      if (currentCoins < neededCoins) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Not enough coins! You need at least $neededCoins coins.';
          });
        }
        return;
      }

      final futures = jobs.map((job) async {
        final prompt = _prompts[job.key] ?? '';
        if (prompt.isEmpty) {
          return MapEntry(job.key, null);
        }
        try {
          final base64 = await _geminiService.generateImageWithUpload(
            prompt,
            [job.file],
          );
          await _firestoreService.deductCoins(costPerImage);
          return MapEntry(job.key, base64);
        } catch (_) {
          return MapEntry(job.key, null);
        }
      }).toList();

      final results = await Future.wait(futures);
      if (!mounted) return;

      setState(() {
        for (final entry in results) {
          final key = entry.key;
          final value = entry.value;
          if (value == null) continue;
          switch (key) {
            case 'front':
              _frontResult = value;
              break;
            case 'side':
              _sideResult = value;
              break;
            case 'back':
              _backResult = value;
              break;
            case 'extra':
              _extraResult = value;
              break;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to generate images. Please try again in a moment.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onAddAllToCatalogue() async {
    final List<String> base64Images = [];
    if (_frontResult != null) base64Images.add(_frontResult!);
    if (_sideResult != null) base64Images.add(_sideResult!);
    if (_backResult != null) base64Images.add(_backResult!);
    if (_extraResult != null) base64Images.add(_extraResult!);

    if (base64Images.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No generated images to add. Please generate first.'),
        ),
      );
      return;
    }

    try {
      final categories = await _firestoreService.getUserCatalogueCategories();
      if (!mounted) return;

      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No catalogue categories found. Please set them up in Catalogue first.'),
          ),
        );
        return;
      }

      String currentCategory = categories.first;
      List<String> currentSubcategories =
          await _firestoreService.getUserCatalogueSubcategories(
        currentCategory,
      );
      if (!mounted) return;

      if (currentSubcategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No subcategories found for "$currentCategory". Please add some in Catalogue first.'),
          ),
        );
        return;
      }

      String? currentSubcategory = currentSubcategories.first;
      String? localError;
      bool confirmed = false;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add all images to catalogue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: currentCategory,
                          items: categories
                              .map((c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            filled: true,
                          ),
                          onChanged: (value) async {
                            if (value == null) return;
                            setSheetState(() {
                              currentCategory = value;
                              currentSubcategory = null;
                              currentSubcategories = [];
                              localError = null;
                            });
                            final subs = await _firestoreService
                                .getUserCatalogueSubcategories(value);
                            if (!mounted) return;
                            setSheetState(() {
                              currentSubcategories = subs;
                              if (currentSubcategories.isNotEmpty) {
                                currentSubcategory = currentSubcategories.first;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: currentSubcategory,
                          items: currentSubcategories
                              .map((s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Subcategory',
                            filled: true,
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              currentSubcategory = value;
                            });
                          },
                        ),
                        if (localError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            localError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentSubcategory == null) {
                                setSheetState(() {
                                  localError =
                                      'Please select a subcategory to continue.';
                                });
                                return;
                              }
                              confirmed = true;
                              Navigator.of(sheetContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Next',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      if (!confirmed || currentSubcategory == null) {
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final files = await Future.wait(
        base64Images.asMap().entries.map(
              (entry) => _createTempFileFromBase64(
                entry.value,
                'ecom_${entry.key}',
              ),
            ),
      );

      final imageUrls = await Future.wait(
        files.map(
          (file) => _firestoreService.uploadProductImage(
            file,
            'EcommerceStudio',
          ),
        ),
      );

      if (!mounted) return;

      final existingProduct = <String, dynamic>{
        'name': '',
        'category': currentCategory,
        'subcategory': currentSubcategory,
        'karat': '',
        'material': '',
        'weight': '',
        'length': '',
        'making_charges': '',
        'stone': '',
        'images': imageUrls,
        'videos': <String>[],
        'description': '',
        'sku': '',
        'stock': '',
        'tags': <String>[],
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
      };

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddSubcategoryProductScreen(
            categoryName: currentCategory,
            subcategoryName: currentSubcategory!,
            existingProduct: existingProduct,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to prepare product for catalogue. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveImage(String label, String base64) async {
    final bytes = base64Decode(base64);
    final result = await ImageGallerySaverPlus.saveImage(bytes,
        name:
            'ecommerce_studio_${label}_${DateTime.now().millisecondsSinceEpoch}');
    if (!(result['isSuccess'] ?? false)) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to save $label image.';
        });
      }
    }
  }

  Future<File> _createTempFileFromBase64(String base64, String nameHint) async {
    final bytes = base64Decode(base64);
    final dir = await getTemporaryDirectory();
    final safeName =
        nameHint.isEmpty ? 'product' : nameHint.replaceAll(' ', '_');
    final path =
        '${dir.path}/ecom_${safeName}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _onAddToCatalogue(String base64) async {
    try {
      final categories = await _firestoreService.getUserCatalogueCategories();
      if (!mounted) return;

      if (categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No catalogue categories found. Please set them up in Catalogue first.'),
          ),
        );
        return;
      }

      String currentCategory = categories.first;
      List<String> currentSubcategories =
          await _firestoreService.getUserCatalogueSubcategories(
        currentCategory,
      );
      if (!mounted) return;

      if (currentSubcategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No subcategories found for "$currentCategory". Please add some in Catalogue first.'),
          ),
        );
        return;
      }

      String? currentSubcategory = currentSubcategories.first;

      final nameController = TextEditingController();
      final descriptionController = TextEditingController();
      String? localError;
      bool confirmed = false;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add to catalogue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: currentCategory,
                          items: categories
                              .map((c) => DropdownMenuItem<String>(
                                    value: c,
                                    child: Text(c),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            filled: true,
                          ),
                          onChanged: (value) async {
                            if (value == null) return;
                            setSheetState(() {
                              currentCategory = value;
                              currentSubcategory = null;
                              currentSubcategories = [];
                              localError = null;
                            });
                            final subs = await _firestoreService
                                .getUserCatalogueSubcategories(value);
                            if (!mounted) return;
                            setSheetState(() {
                              currentSubcategories = subs;
                              if (currentSubcategories.isNotEmpty) {
                                currentSubcategory = currentSubcategories.first;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: currentSubcategory,
                          items: currentSubcategories
                              .map((s) => DropdownMenuItem<String>(
                                    value: s,
                                    child: Text(s),
                                  ))
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Subcategory',
                            filled: true,
                          ),
                          onChanged: (value) {
                            setSheetState(() {
                              currentSubcategory = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Product name',
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Description (optional)',
                            filled: true,
                          ),
                        ),
                        if (localError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            localError!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty || currentSubcategory == null) {
                                setSheetState(() {
                                  localError =
                                      'Please enter a name and select a subcategory.';
                                });
                                return;
                              }
                              confirmed = true;
                              Navigator.of(sheetContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Add to catalogue',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );

      if (!confirmed || currentSubcategory == null) {
        return;
      }

      final name = nameController.text.trim();
      final description = descriptionController.text.trim();

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final file = await _createTempFileFromBase64(base64, name);
      final imageUrl = await _firestoreService.uploadProductImage(file, name);

      final productId =
          'PRD${DateTime.now().millisecondsSinceEpoch.toString()}';

      final productData = {
        'product_id': productId,
        'name': name.isEmpty ? 'Ecommerce Studio Product' : name,
        'subcategory': currentSubcategory,
        'karat': '',
        'material': '',
        'weight': '',
        'length': '',
        'making_charges': '',
        'stone': '',
        'images': [imageUrl],
        'videos': <String>[],
        'description': description,
        'sku': '',
        'stock': '',
        'tags': <String>[],
        'imageUrl': imageUrl,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _firestoreService.addProduct(currentCategory, productData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added to catalogue.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to add product to catalogue. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSection(String key, String title, String subtitle, File? image) {
    return GestureDetector(
      onTap: () => _pickImage(key),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(image, fit: BoxFit.cover),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white70, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildResultCard(String label, String? base64) {
    if (base64 == null) return const SizedBox.shrink();

    final bytes = base64Decode(base64);

    return Card(
      color: AppTheme.secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.only(
              right: 4.0,
              top: 4.0,
              bottom: 4.0,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () => _saveImage(label, base64),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPrompts) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              title: const Text('Ecommerce Studio'),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'front',
                      'Add front side',
                      'Upload the front view of the product',
                      _frontImage,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'side',
                      'Add side angle',
                      'Upload a side-angle view of the product',
                      _sideImage,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'back',
                      'Add back',
                      'Upload the back view of the product',
                      _backImage,
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      'extra',
                      'Add extra angle',
                      'Optional extra view (top, macro, or lifestyle)',
                      _extraImage,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Generate',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildResultCard('Front result', _frontResult),
                    const SizedBox(height: 12),
                    _buildResultCard('Side result', _sideResult),
                    const SizedBox(height: 12),
                    _buildResultCard('Back result', _backResult),
                    const SizedBox(height: 12),
                    _buildResultCard('Extra result', _extraResult),
                    const SizedBox(height: 16),
                    if (_hasAnyResult)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _onAddAllToCatalogue,
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text(
                            'Add all to catalogue',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionJob {
  final String key;
  final File file;

  _SectionJob(this.key, this.file);
}
