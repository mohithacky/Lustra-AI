import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/gemini_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/services/connectivity_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/widgets/offline_dialog.dart';

class AdShootGenerationScreen extends StatefulWidget {
  final Template template;

  const AdShootGenerationScreen({Key? key, required this.template})
      : super(key: key);

  @override
  _AdShootGenerationScreenState createState() =>
      _AdShootGenerationScreenState();
}

class _AdShootGenerationScreenState extends State<AdShootGenerationScreen> {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();
  final List<TextEditingController> _textControllers = [];
  final List<TextEditingController> _dynamicTextControllers = [];
  final List<TextEditingController> _phoneControllers = [];
  final List<String> _dynamicAdTextHints = [];
  final TextEditingController _instaIdController = TextEditingController();
  Map<String, dynamic>? _shopDetails;
  String? _generatedImage;
  bool _isLoading = false;
  File? _userImage;
  int? _remainingCoins;
  String? _errorMessage;
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
        _phoneControllers.clear();
        final initialPhone = _shopDetails?['phoneNumber']?.toString();
        if (initialPhone != null && initialPhone.isNotEmpty) {
          _phoneControllers.add(TextEditingController(text: initialPhone));
        } else {
          _phoneControllers.add(TextEditingController());
        }
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
    for (var controller in _phoneControllers) {
      controller.dispose();
    }
    _instaIdController.dispose();
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
    if (!await ConnectivityService.isConnected()) {
      if (mounted) showOfflineDialog(context);
      return;
    }

    if (_userImage == null) {
      setState(() {
        _errorMessage = 'Please upload an image to generate a poster.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Check if user has enough coins
      final userDoc = await _firestoreService.getUserStream().first;
      final userData = userDoc.data() as Map<String, dynamic>?;
      final currentCoins = userData?['coins'] ?? 0;

      if (currentCoins < 5) {
        setState(() {
          _errorMessage =
              'Not enough coins! Please purchase more to generate images.';
          _isLoading = false;
        });
        return;
      }

      // 2. Proceed with image generation
      final phoneNumbers = _phoneControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      String modifiedPrompt;
      if (phoneNumbers.length == 1 &&
          widget.template.promptForSinglePhoneNumber.isNotEmpty) {
        modifiedPrompt = widget.template.promptForSinglePhoneNumber;
      } else if (phoneNumbers.length > 1 &&
          widget.template.promptForMultiplePhoneNumbers.isNotEmpty) {
        modifiedPrompt = widget.template.promptForMultiplePhoneNumbers;
      } else {
        modifiedPrompt = widget.template.prompt;
      }

      final Map<String, dynamic> replacements = {};

      // 1. Gather details from Firestore (excluding phone number)
      if (_shopDetails != null) {
        _shopDetails!.forEach((key, value) {
          if (key != 'phoneNumber') {
            // Exclude the old phone number field
            replacements[key] = value?.toString() ?? '';
          }
        });
      }

      // 1a. Gather phone numbers from the new text controllers
      for (int i = 0; i < phoneNumbers.length; i++) {
        replacements['phoneNumber${i + 1}'] = phoneNumbers[i];
      }

      // 2. Gather details from dropdowns
      if (widget.template.hasMetalTypeDropdown) {
        replacements['Discounts on'] = _selectedDiscounts.join(', ');
      }

      // 2a. Select a random line from the linesList if available
      if (widget.template.linesList.isNotEmpty) {
        final random = Random();
        final index = random.nextInt(widget.template.linesList.length);
        replacements['good_line'] = widget.template.linesList[index];
      }

      replacements['instaID'] = _instaIdController.text;

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
        if (value is List<String>) {
          modifiedPrompt =
              modifiedPrompt.replaceAll('{$key}', value.join(' / '));
        } else if (value is String) {
          modifiedPrompt = modifiedPrompt.replaceAll('{$key}', value);
        }
      });

      // Append a strong instruction for all features to be included
      if (widget.template.hasDynamicTextFields &&
          replacements.containsKey('features')) {
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
        int end = (i + chunkSize < modifiedPrompt.length)
            ? i + chunkSize
            : modifiedPrompt.length;
        print(modifiedPrompt.substring(i, end));
      }
      print('--- Modified Prompt End ---');

      final generatedImageBase64 =
          await _geminiService.generateAdShootImageWithoutImage(modifiedPrompt);

      // Decode the generated image
      final generatedImageBytes = base64Decode(generatedImageBase64);
      final generatedImage = img.decodeImage(generatedImageBytes);

      if (generatedImage == null) {
        throw Exception('Failed to decode generated image.');
      }

      // Load the user's logo and overlay it
      if (_userImage != null) {
        final logoImageBytes = await _userImage!.readAsBytes();
        final logoImage = img.decodeImage(logoImageBytes);

        if (logoImage != null) {
          // Resize logo to be 1/8th of the generated image's width
          final logoSize = (generatedImage.width / 8).round();
          var resizedLogo =
              img.copyResize(logoImage, width: logoSize, height: logoSize);

          // Ensure the logo has an alpha channel for transparency
          if (resizedLogo.format != img.Format.uint8 ||
              resizedLogo.numChannels != 4) {
            final cmd = img.Command()
              ..image(resizedLogo)
              ..convert(format: resizedLogo.format, numChannels: 4);
            final rgbaLogo = await cmd.getImage();
            if (rgbaLogo != null) {
              resizedLogo = rgbaLogo;
            }
          }

          // Crop the logo into a circle
          final circularLogo = img.copyCropCircle(resizedLogo);

          // Add a small margin
          const margin = 24;

          // Overlay the circular logo onto the top-left corner
          img.compositeImage(generatedImage, circularLogo,
              dstX: margin, dstY: margin);
        }
      }

      // Encode the final image back to Base64
      final finalImageBytes = img.encodePng(generatedImage);
      final finalImageBase64 = base64Encode(finalImageBytes);

      // 2. Deduct coins after successful generation
      try {
        await _firestoreService.deductCoins(5);
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Image generated, but failed to deduct coins. Please contact support.';
            // We still show the image, but flag the coin issue.
          });
        }
      }

      // 3. Fetch the new coin balance to display it
      final updatedUserDoc = await _firestoreService.getUserStream().first;
      final updatedUserData = updatedUserDoc.data() as Map<String, dynamic>?;

      if (mounted) {
        setState(() {
          _generatedImage = finalImageBase64;
          _remainingCoins = updatedUserData?['coins'] ?? 0;
        });
      }
    } catch (e, st) {
      print('UPLOAD_CALL_ERROR: $e');
      print(st);
      setState(() {
        _errorMessage =
            'Failed to generate image. The AI model may be overloaded. Please try again later.';
      });
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
                        icon: const Icon(Icons.share,
                            color: AppTheme.accentColor),
                        onPressed: _shareImage,
                        tooltip: 'Share',
                      ),
                      if (_remainingCoins != null)
                        Chip(
                          avatar: Icon(Icons.monetization_on,
                              color: AppTheme.accentColor.withOpacity(0.8),
                              size: 18),
                          label: Text('$_remainingCoins Coins Left'),
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.1),
                        ),
                      IconButton(
                        icon: const Icon(Icons.download,
                            color: AppTheme.accentColor),
                        onPressed: _saveImage,
                        tooltip: 'Download',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 16.0,
                      alignment: WrapAlignment.center,
                      children: [
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generateImage,
                          child: const Text('Generate Again'),
                        ),
                      ],
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
                  TextFormField(
                    controller: _instaIdController,
                    decoration: const InputDecoration(
                      hintText: 'Enter Instagram ID',
                      labelText: 'Instagram ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPhoneNumbersSection(),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (widget.template.hasMetalTypeDropdown)
                    _buildDiscountMultiSelect(),
                  if (widget.template.hasDynamicTextFields)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text('Add New Feature:',
                                style: Theme.of(context).textTheme.titleLarge),
                            if (widget.template.hasDynamicTextFields)
                              IconButton(
                                icon: const Icon(Icons.add_circle,
                                    color: AppTheme.accentColor),
                                onPressed: _showAddFeatureDialog,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...widget.template.adTextHints
                            .asMap()
                            .entries
                            .map((entry) {
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
                Text('Shop Details',
                    style: Theme.of(context).textTheme.titleLarge),
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
            Text(
                'Phone: ${_phoneControllers.isNotEmpty ? _phoneControllers.first.text : 'N/A'}'),
          ],
        ),
      ),
    );
  }

  void _showEditShopDetailsDialog() {
    if (_shopDetails == null) return;

    final nameController =
        TextEditingController(text: _shopDetails!['shopName']);
    final addressController =
        TextEditingController(text: _shopDetails!['shopAddress']);
    // Use the first phone controller for the dialog
    final phoneController = _phoneControllers.isNotEmpty
        ? TextEditingController(text: _phoneControllers.first.text)
        : TextEditingController();

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
                    // No longer storing phoneNumber directly in _shopDetails
                  };
                  // Update the first phone number in the main list
                  if (_phoneControllers.isNotEmpty) {
                    _phoneControllers.first.text = phoneController.text;
                  } else {
                    _phoneControllers
                        .add(TextEditingController(text: phoneController.text));
                  }
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
                    Text('Add Your Logo'),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPhoneNumbersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Numbers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        ..._phoneControllers.asMap().entries.map((entry) {
          int index = entry.key;
          TextEditingController controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Phone Number ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                if (_phoneControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        controller.dispose();
                        _phoneControllers.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
          );
        }).toList(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.add, color: AppTheme.accentColor),
            label: const Text('Add Another Number',
                style: TextStyle(color: AppTheme.accentColor)),
            onPressed: () {
              setState(() {
                _phoneControllers.add(TextEditingController());
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountMultiSelect() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Discounts on',
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.accentColor),
              onPressed: _showDiscountMultiSelectDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: _selectedDiscounts
              .map((item) => Chip(label: Text(item)))
              .toList(),
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
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Feature '),
          content: TextFormField(
            controller: valueController,
            decoration: const InputDecoration(hintText: 'Enter feature'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = valueController.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    final nextIndex = widget.template.adTextHints.length +
                        _dynamicAdTextHints.length +
                        1;
                    _dynamicAdTextHints.add('Feature $nextIndex');
                    _dynamicTextControllers
                        .add(TextEditingController(text: text));
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
