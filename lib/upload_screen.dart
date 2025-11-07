import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lustra_ai/widgets/glassmorphic_container.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/widgets/wave_clipper.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lustra_ai/screens/jewellery_category_selection_screen.dart';
import 'package:lustra_ai/services/used_template_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/services/gemini_service.dart';
import 'package:lustra_ai/screens/image_viewer_screen.dart';
import 'package:image/image.dart' as img;
import 'package:lustra_ai/services/backend_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:infinite_carousel/infinite_carousel.dart';
import 'package:lustra_ai/widgets/animated_popup.dart';
import 'package:lustra_ai/screens/onboarding_screen.dart';

class UploadScreen extends StatefulWidget {
  final String shootType;
  final Template? selectedTemplate;
  final bool showTemplateSelection;
  final String? initialPrompt;

  UploadScreen({
    Key? key,
    required this.shootType,
    this.selectedTemplate,
    this.showTemplateSelection = true,
    this.initialPrompt,
  }) : super(key: key);

  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<File?> _images = [];
  List<String> _generatedImages = [];
  bool _isLoading = false;
  Template? _selectedTemplate;
  String? _logoUrl;
  final _videoPromptController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isBatchPhotoshoot = false;
  String? _errorMessage;
  final Set<int> _regeneratingIndices = {};

  // Video state
  VideoPlayerController? _videoController;
  String? _videoUrl;
  bool _isGeneratingVideo = false;
  final picker = ImagePicker();
  final UsedTemplateService _usedTemplateService = UsedTemplateService();
  final FirestoreService _firestoreService = FirestoreService();
  final GeminiService _geminiService = GeminiService();

  Future<void> _addAllLogos() async {
    for (int i = 0; i < _generatedImages.length; i++) {
      await _addLogoToImage(i);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logos added to all images!')),
    );
  }

  Future<void> _addWeightToImage(int index, String weight) async {
    if (_generatedImages.length <= index || weight.isEmpty) return;

    try {
      final generatedImageBytes = base64Decode(_generatedImages[index]);
      final mainImage = img.decodeImage(generatedImageBytes);

      if (mainImage == null) {
        throw Exception('Failed to decode image.');
      }

      // Simple positioning for now, can be improved
      img.drawString(
        mainImage,
        '$weight g',
        font: img.arial48,
        x: 20, // Position on the left
        y: mainImage.height - 70, // Adjust Y position for new font size
        color: img.ColorRgb8(255, 255, 255),
      );

      final newImageBytes = img.encodeJpg(mainImage);
      final newBase64Image = base64Encode(newImageBytes);

      setState(() {
        _generatedImages[index] = newBase64Image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight added successfully!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error adding weight. Please try again.';
      });
    }
  }

  void _showAddLogoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AnimatedPopup(
          message: 'Add the logo of your shop first.',
          onActionPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const OnboardingApp(),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addLogoToImage(int index) async {
    if (_generatedImages.length <= index) return;

    if (_logoUrl == null || _logoUrl!.isEmpty) {
      _showAddLogoDialog();
      return;
    }

    try {
      final response = await http.get(Uri.parse(_logoUrl!));
      if (response.statusCode != 200) {
        throw Exception('Failed to download logo.');
      }
      final logoBytes = response.bodyBytes;

      final generatedImageBytes = base64Decode(_generatedImages[index]);
      final mainImage = img.decodeImage(generatedImageBytes);
      final logoImage = img.decodeImage(logoBytes);

      if (mainImage == null || logoImage == null) {
        throw Exception('Failed to decode images.');
      }

      final logoWidth = mainImage.width ~/ 5; // Doubled the size
      var resizedLogo = img.copyResize(logoImage, width: logoWidth);

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

      img.compositeImage(
        mainImage,
        circularLogo,
        dstX: mainImage.width - circularLogo.width - 20, // 20px margin
        dstY: mainImage.height - circularLogo.height - 20, // 20px margin
      );

      final newImageBytes = img.encodeJpg(mainImage);
      final newBase64Image = base64Encode(newImageBytes);

      setState(() {
        _generatedImages[index] = newBase64Image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo added successfully!')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error adding logo. Please try again.';
      });
    }
  }

  Future<void> _shareAllImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      List<XFile> filesToShare = [];
      for (int i = 0; i < _generatedImages.length; i++) {
        final file =
            await File('${tempDir.path}/generated_image_$i.jpg').create();
        await file.writeAsBytes(base64Decode(_generatedImages[i]));
        filesToShare.add(XFile(file.path));
      }
      await Share.shareXFiles(filesToShare, text: 'Check out my new designs!');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error sharing images. Please try again.';
        });
      }
    }
  }

  Future<void> _shareImage(int index) async {
    if (_generatedImages.length <= index) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/generated_image.jpg').create();
      await file.writeAsBytes(base64Decode(_generatedImages[index]));

      final xFile = XFile(file.path);

      await Share.shareXFiles([xFile], text: 'Check out my new design!');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error sharing image. Please try again.';
        });
      }
    }
  }

  Future<void> _saveAllImages() async {
    var status = await Permission.photos.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      int successCount = 0;
      for (int i = 0; i < _generatedImages.length; i++) {
        final result = await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(base64Decode(_generatedImages[i])),
          quality: 100,
          name: "generated_image_${DateTime.now().millisecondsSinceEpoch}_$i",
        );
        if (result['isSuccess'] ?? false) {
          successCount++;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$successCount of ${_generatedImages.length} images saved to gallery!')),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Storage permission was denied.';
        });
      }
    }
  }

  Future<void> _saveImage(int index) async {
    if (_generatedImages.length <= index) return;

    var status = await Permission.photos.request();

    if (status.isPermanentlyDenied || status.isRestricted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(base64Decode(_generatedImages[index])),
        quality: 100,
        name: "generated_image_${DateTime.now().millisecondsSinceEpoch}",
      );
      if (mounted && (result['isSuccess'] ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved to gallery!')),
        );
      } else if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to save image. Please check storage permissions.';
        });
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Storage permission is required. Please enable it in your device settings.';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Storage permission was denied.';
        });
      }
    }
  }

  Future<void> _downloadVideo() async {
    if (_videoUrl == null) {
      setState(() {
        _errorMessage = 'No video is available to download.';
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading video...')),
    );

    try {
      // Request storage permissions
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        // For Android 13+ and iOS, photos permission is needed.
        status = await Permission.photos.request();
      }

      if (status.isGranted) {
        final response = await http.get(Uri.parse(_videoUrl!));
        if (response.statusCode == 200) {
          final result = await ImageGallerySaverPlus.saveImage(
            response.bodyBytes,
            name: "video_${DateTime.now().millisecondsSinceEpoch}",
          );

          if (mounted && (result['isSuccess'] ?? false)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video saved to gallery!')),
            );
          } else if (mounted) {
            setState(() {
              _errorMessage = 'Failed to save video: ${result['errorMessage']}';
            });
          }
        } else {
          throw Exception('Failed to download video: ${response.reasonPhrase}');
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Storage permission was denied.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error downloading video. Please try again.';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null) {
      _videoPromptController.text = widget.initialPrompt!;
    }
    // The custom prompt controller is for the image, not the video.
    // We should not be setting it with the reel's prompt.
    // _customPromptController.text = widget.initialPrompt ?? '';
    _selectedTemplate = widget.selectedTemplate;
    int imageCount = 1;
    if (_selectedTemplate != null) {
      imageCount = _selectedTemplate!.numberOfJewelleries;
    } else {
    }
    _images = List.generate(imageCount, (_) => null);
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final userDetails = await _firestoreService.getUserDetails();
    if (mounted &&
        userDetails != null &&
        userDetails['shopDetailsFilled'] == true) {
      final logoUrl = userDetails['logoUrl'];
      if (logoUrl != null && logoUrl.isNotEmpty) {
        setState(() {
          _logoUrl = logoUrl;
        });
      }
    }
  }

  @override
  void didUpdateWidget(UploadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTemplate != oldWidget.selectedTemplate) {
      setState(() {
        _selectedTemplate = widget.selectedTemplate;
        int imageCount = _selectedTemplate?.numberOfJewelleries ?? 1;
        _images = List.generate(imageCount, (_) => null);
      });
    }
  }

  @override
  void dispose() {
    _videoPromptController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _generateVideo() async {
    if (_generatedImages.isEmpty) return;

    setState(() {
      _isGeneratingVideo = true;
      _videoUrl = null;
      _videoController?.dispose();
      _videoController = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendBaseUrl/generate-video'),
      );
      request.fields['prompt'] = _videoPromptController.text;
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (idToken != null) {
        request.headers['Authorization'] = 'Bearer $idToken';
      }

      // Use the first generated image for the video generation.
      final imageBytes = base64Decode(_generatedImages.first);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'generated_image.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      final response = await request.send();

      if (response.statusCode == 202) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        final taskId = data['taskId'];
        _pollVideoStatus(taskId);
      } else {
        final responseBody = await response.stream.bytesToString();
        throw Exception(
            'Failed to start video generation: ${response.reasonPhrase} - $responseBody');
      }
    } catch (e) {
      setState(() {
        _isGeneratingVideo = false;
        _errorMessage = 'Error generating video. Please try again later.';
      });
    }
  }

  Future<void> _pollVideoStatus(String taskId) async {
    while (_isGeneratingVideo) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final idToken =
            await FirebaseAuth.instance.currentUser?.getIdToken(true);
        final response = await http.get(
          Uri.parse('$backendBaseUrl/video-status/$taskId'),
          headers: {
            if (idToken != null) 'Authorization': 'Bearer $idToken',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          var status = "";
          if (data.containsKey('status')) {
            status = data['status'];
            debugPrint("Status: $status");
          } else {
            status = data['result']['data']['status'];
            debugPrint("Status: $status");
          }

          if (status == 'completed') {
            // The backend now nests the full Hailuo result under the 'result' key.
            // The full webhook payload is in the 'result' field.
            // The new structure is result -> data -> output -> video_url
            final hailuoResult = data['result']['data'];
            final videoResultUrl = hailuoResult['output']['video_url'];
            debugPrint("Video URL: $videoResultUrl");
            // The video_url from Hailuo should be a full URL, so we don't need to prepend the backend address.
            setState(() {
              _videoUrl = videoResultUrl;
              _isGeneratingVideo = false;
            });
            _initializeVideoPlayer();
            break; // Exit loop
          } else if (status == 'failed') {
            throw Exception('Video generation failed: ${data['result']}');
          }
        } else {
          throw Exception(
              'Failed to get video status: ${response.reasonPhrase}');
        }
      } catch (e) {
        setState(() {
          _isGeneratingVideo = false;
        });
        setState(() {
          _errorMessage = 'Error checking video status. Please try again.';
        });
        return; // Exit polling loop on error
      }
    }
  }

  void _initializeVideoPlayer() {
    if (_videoUrl == null) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoUrl!))
      ..initialize().then((_) {
        setState(() {});
        _videoController!.play();
        _videoController!.setLooping(true);
      });
  }

  Future<void> _showVideoPromptDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Generate Video'),
          content: TextField(
            controller: _videoPromptController,
            decoration:
                const InputDecoration(hintText: "Enter a prompt for the video"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Generate'),
              onPressed: () {
                Navigator.of(context).pop();
                _generateVideo();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickMultipleImages() async {
    final List<XFile> pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var file in pickedFiles) {
          _images.add(File(file.path));
        }
        _generatedImages = []; // Reset on new image
      });
    }
  }

  Future<void> _pickImage(ImageSource source, int index) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (_isBatchPhotoshoot) {
          _images.add(File(pickedFile.path));
        } else {
          _images[index] = File(pickedFile.path);
        }
        _generatedImages = []; // Reset on new image
      });
    }
  }

  void _showImageSourceDialog(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo Library'),
              onTap: () {
                _pickImage(ImageSource.gallery, index);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () {
                _pickImage(ImageSource.camera, index);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateImage() async {
    if (_images.any((img) => img == null) ||
        (_selectedTemplate == null && !_isBatchPhotoshoot)) {
      setState(() {
        _errorMessage =
            'Please upload all required images and select a template.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedImages = [];
      _errorMessage = null; // Clear previous errors
    });

    if (_isBatchPhotoshoot) {
      await _generateBatchImages();
    } else {
      await _generateSingleImage(_images.first!, 0);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _generateBatchImages() async {
    for (int i = 0; i < _images.length; i++) {
      if (_images[i] != null) {
        await _generateSingleImage(_images[i]!, i);
        if (i < _images.length - 1) {
          // Add delay between generations
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }
  }

  Future<void> _generateSingleImage(File image, int index) async {
    setState(() {
      _regeneratingIndices.add(index);
    });
    try {
      // 1. Check if user has enough coins
      final userDoc = await _firestoreService.getUserStream().first;
      final userData = userDoc.data() as Map<String, dynamic>?;
      final currentCoins = userData?['coins'] ?? 0;

      if (currentCoins < 5) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Not enough coins! Please purchase more to generate images.';
          });
        }
        return;
      }

      final prompt = """
${_selectedTemplate!.prompt}

Use only the single uploaded jewellery image for this generation.
Do not incorporate any other jewellery pieces or elements from previous requests.
Focus solely on the provided image.
""";

      final generatedImageBase64 =
          await _geminiService.generateImageWithUpload(prompt, [image]);

      // 2. Deduct coins after successful generation
      await _firestoreService.deductCoins(5);

      setState(() {
        // Ensure list is long enough
        if (_generatedImages.length <= index) {
          _generatedImages
              .addAll(List.filled(index - _generatedImages.length + 1, ''));
        }
        _generatedImages[index] = generatedImageBase64;
      });

      if (index == 0) {
        // Only log template use once
        await _usedTemplateService.addUsedTemplate(_selectedTemplate!);
        await _firestoreService.incrementUseCount(
            _selectedTemplate!.id, _selectedTemplate!.author);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'An unexpected error occurred for image ${index + 1}.';
        });
      }
    } finally {
      setState(() {
        _regeneratingIndices.remove(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppTheme.backgroundColor),
          SizedBox(
            height: 400,
            child: ClipPath(
              clipper: WaveClipper(),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: Text(widget.shootType),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : _generatedImages.isNotEmpty
                          ? _buildResultsUI()
                          : _buildUploadUI(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('1. Upload Your Jewellery'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch PhotoShoot',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
              ),
              Switch(
                value: _isBatchPhotoshoot,
                onChanged: (value) {
                  setState(() {
                    _isBatchPhotoshoot = value;
                    if (_isBatchPhotoshoot) {
                      _images = []; // Initialize as empty list for multi-select
                    } else {
                      _images = List.generate(1, (_) => null);
                    }
                  });
                },
              ),
            ],
          ),
          if (_isBatchPhotoshoot) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Images'),
              onPressed: _pickMultipleImages,
            ),
            const SizedBox(height: 16),
            if (_images.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 8, top: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(_images[index]!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _images.removeAt(index);
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
          ] else ...[
            ...List.generate(_images.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildImageUploader(index),
              );
            }),
          ],
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 24),
          if (widget.showTemplateSelection)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('2. Choose Your Template'),
                const SizedBox(height: 16),
                _buildTemplateList(),
              ],
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_images.every((img) => img != null) &&
                      _selectedTemplate != null)
                  ? _generateImage
                  : null,
              child: const Text('Apply Template'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageUploader(int index) {
    return GestureDetector(
      onTap: () => _showImageSourceDialog(index),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 180,
        child: _images[index] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(_images[index]!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white70, size: 48),
                  const SizedBox(height: 12),
                  Text('Upload Jewellery Image ${index + 1}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.black45)),
                ],
              ),
      ),
    );
  }

  Widget _buildResultsUI() {
    return SingleChildScrollView(
        child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSectionTitle('Generation Result'),
        ),
        if (_generatedImages.isNotEmpty)
          SizedBox(
            height: 450, // Adjust height to fit carousel and buttons
            child: InfiniteCarousel.builder(
              itemCount: _generatedImages.length,
              itemExtent: MediaQuery.of(context).size.width * 0.8,
              center: true,
              anchor: 0.0,
              velocityFactor: 0.2,
              loop: false,
              itemBuilder: (context, itemIndex, realIndex) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildGeneratedImageCard(itemIndex),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        if (_generatedImages.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _shareAllImages,
                icon: const Icon(Icons.share),
              ),
              IconButton(
                onPressed: _saveAllImages,
                icon: const Icon(
                  Icons.download,
                ),
              ),
              IconButton(
                onPressed: _addAllLogos,
                icon: const Icon(Icons.add_circle_outline),
              )
            ],
          ),
        const SizedBox(height: 20),
        // if (_videoController != null && _videoController!.value.isInitialized)
        //   _buildVideoPlayer()
        // else if (_isGeneratingVideo)
        //   const Padding(
        //     padding: EdgeInsets.symmetric(vertical: 24.0),
        //     child: Column(
        //       children: [
        //         CircularProgressIndicator(color: Colors.white),
        //         SizedBox(height: 16),
        //         Text('Generating video...'),
        //       ],
        //     ),
        //   )
        // else if (_generatedImages.isNotEmpty)
        //   Padding(
        //     padding: const EdgeInsets.all(16.0),
        //     child: ElevatedButton.icon(
        //       icon: const Icon(Icons.videocam_outlined),
        //       label: Text(widget.initialPrompt != null
        //           ? 'Generate Your Reel'
        //           : 'Animate First Image'),
        //       onPressed: (widget.initialPrompt != null)
        //           ? _generateVideo
        //           : _showVideoPromptDialog,
        //     ),
        //   ),
        // Padding(
        //   padding: const EdgeInsets.all(16.0),
        //   child: TextButton.icon(
        //     icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
        //     onPressed: () => setState(() {
        //       _images = List.generate(_isBatchPhotoshoot ? 0 : 1, (_) => null);
        //       _generatedImages = [];
        //       _videoUrl = null;
        //       _videoController?.dispose();
        //       _videoController = null;
        //       _isGeneratingVideo = false;
        //       _videoPromptController.clear();
        //     }),
        //     label: Text('Start Over',
        //         style: Theme.of(context)
        //             .textTheme
        //             .bodyLarge
        //             ?.copyWith(color: Colors.white70)),
        //   ),
        // ),
      ],
    ));
  }

  Widget _buildVideoPlayer() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 350,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: VideoPlayer(_videoController!),
            ),
          ),
          IconButton(
            icon: Icon(
              _videoController!.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              color: Colors.white.withOpacity(0.8),
              size: 60,
            ),
            onPressed: () {
              setState(() {
                _videoController!.value.isPlaying
                    ? _videoController!.pause()
                    : _videoController!.play();
              });
            },
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.download_rounded,
                  color: Colors.white, size: 32),
              onPressed: _downloadVideo,
              tooltip: 'Download Video',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedImageCard(int index) {
    return Column(
      children: [
        GlassmorphicContainer(
          width: double.infinity,
          height: 300,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(
                          imageBase64: _generatedImages[index]),
                    ),
                  );
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        base64Decode(_generatedImages[index]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    if (_regeneratingIndices.contains(index))
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () => _shareImage(index),
                      icon: const Icon(Icons.share, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => _saveImage(index),
                      icon: const Icon(Icons.download, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () => _addLogoToImage(index),
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white),
                    ),
                    IconButton(
                      onPressed: () {
                        if (_images.length > index && _images[index] != null) {
                          _generateSingleImage(_images[index]!, index);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Original image not found for regeneration.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Weight (grams)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _addWeightToImage(index, _weightController.text);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateList() {
    final shootTypes = ['PhotoShoot', 'AdShoot', 'ProductShoot'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: shootTypes.map((shootType) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final selectedTemplate =
                  await Navigator.of(context).push<Template>(
                MaterialPageRoute(
                  builder: (context) =>
                      JewelleryCategorySelectionScreen(shootType: shootType),
                ),
              );

              if (selectedTemplate != null) {
                if (mounted) {
                  setState(() {
                    _selectedTemplate = selectedTemplate;
                  });
                }
              }
            },
            child: Text(shootType),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(color: Colors.white70, fontWeight: FontWeight.bold),
    );
  }
}
