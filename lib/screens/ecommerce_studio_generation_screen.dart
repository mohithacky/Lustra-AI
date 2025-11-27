import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lustra_ai/services/gemini_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';

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
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () => _saveImage(label, base64),
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
