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
import 'package:lustra_ai/screens/image_viewer_screen.dart';
import 'package:image/image.dart' as img;

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
  }) : super(key: key) {
    print('--- UploadScreen constructor ---');
    if (selectedTemplate != null) {
      print(
          'Constructor received template: "${selectedTemplate!.title}" with ${selectedTemplate!.numberOfJewelleries} jewelleries.');
    } else {
      print('Constructor received no template.');
    }
  }

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
  bool _isBatchPhotoshoot = false;
  int _numberOfImages = 1; // Default to 1 image
  String? _errorMessage;

  // Video state
  VideoPlayerController? _videoController;
  String? _videoUrl;
  bool _isGeneratingVideo = false;
  final picker = ImagePicker();
  final UsedTemplateService _usedTemplateService = UsedTemplateService();
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _addLogoToImage(int index) async {
    if (_generatedImages.length <= index) return;

    // Check if the logo URL from shop details is available
    if (_logoUrl == null || _logoUrl!.isEmpty) {
      setState(() {
        _errorMessage = 'No logo found. Please upload a logo in your Shop Details.';
      });
      return;
    }

    try {
      // 1. Download the logo image
      final response = await http.get(Uri.parse(_logoUrl!));
      if (response.statusCode != 200) {
        throw Exception('Failed to download logo.');
      }
      final logoBytes = response.bodyBytes;

      // 2. Decode images
      final generatedImageBytes = base64Decode(_generatedImages[index]);
      final mainImage = img.decodeImage(generatedImageBytes);
      final logoImage = img.decodeImage(logoBytes);

      if (mainImage == null || logoImage == null) {
        throw Exception('Failed to decode images.');
      }

      // 3. Resize logo to be half the previous size (1/10 of the main image width)
      final logoWidth = mainImage.width ~/ 10;
      final resizedLogo = img.copyResize(logoImage, width: logoWidth);

      // 4. Overlay logo on the bottom right corner
      img.compositeImage(
        mainImage,
        resizedLogo,
        dstX: mainImage.width - resizedLogo.width - 20, // 20px margin
        dstY: mainImage.height - resizedLogo.height - 20, // 20px margin
      );

      // 5. Encode the image back to a base64 string
      final newImageBytes = img.encodeJpg(mainImage);
      final newBase64Image = base64Encode(newImageBytes);

      // 6. Update the state
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

  Future<void> _saveImage(int index) async {
    if (_generatedImages.length <= index) return;

    // For Android 13+, request photos permission. For older versions, storage is sufficient.
    // This requires checking the Android version, but for simplicity and broader compatibility,
    // we can request photos permission, which gracefully handles older versions.
    var status = await Permission.photos.request();

    // If photos permission is not available (on older Android), fall back to storage.
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
          _errorMessage = 'Failed to save image. Please check storage permissions.';
        });
      }
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Storage permission is required. Please enable it in your device settings.';
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
    print('--- _UploadScreenState initState ---');
    _selectedTemplate = widget.selectedTemplate;
    int imageCount = 1;
    if (_selectedTemplate != null) {
      imageCount = _selectedTemplate!.numberOfJewelleries;
      print(
          'initState: Template is "${_selectedTemplate!.title}", requires $imageCount images.');
    } else {
      print('initState: No template, defaulting to 1 image.');
    }
    _images = List.generate(imageCount, (_) => null);
    print('initState: Image list initialized with ${_images.length} slots.');
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
    print('--- _UploadScreenState didUpdateWidget ---');
    if (widget.selectedTemplate != oldWidget.selectedTemplate) {
      print('Template has changed.');
      setState(() {
        _selectedTemplate = widget.selectedTemplate;
        int imageCount = _selectedTemplate?.numberOfJewelleries ?? 1;
        _images = List.generate(imageCount, (_) => null);
        print(
            'didUpdateWidget: Image list re-initialized with ${_images.length} slots.');
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
        Uri.parse(
            'https://central-miserably-sunbird.ngrok-free.app/generate-video'),
      );
      request.fields['prompt'] = _videoPromptController.text;

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
        final response = await http.get(
          Uri.parse(
              'https://central-miserably-sunbird.ngrok-free.app/video-status/$taskId'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          var status = "";
          print("Data:$data");
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

  Future<void> _pickImage(ImageSource source, int index) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _images[index] = File(pickedFile.path);
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
        _errorMessage = 'Please upload all required images and select a template.';
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
    try {
      // 1. Check if user has enough coins
      final userDoc = await _firestoreService.getUserStream().first;
      final userData = userDoc.data() as Map<String, dynamic>?;
      final currentCoins = userData?['coins'] ?? 0;

      if (currentCoins < 5) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Not enough coins! Please purchase more to generate images.';
          });
        }
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://central-miserably-sunbird.ngrok-free.app/upload'),
      );
      final prompt = """
${_selectedTemplate!.prompt}

Use only the single uploaded jewellery image for this generation.
Do not incorporate any other jewellery pieces or elements from previous requests.
Focus solely on the provided image.
""";
      request.fields['prompt'] = prompt;
      print('Prompt for image ${index + 1}: $prompt');
      request.files.add(await http.MultipartFile.fromPath(
        'image_0', // Always use image_0 for single image endpoint
        image.path,
        contentType: MediaType('image', 'jpeg'),
      ));
      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final decodedResponse = jsonDecode(responseBody);

        // 2. Deduct coins after successful generation
        await _firestoreService.deductCoins(5);

        setState(() {
          // Ensure list is long enough
          if (_generatedImages.length <= index) {
            _generatedImages
                .addAll(List.filled(index - _generatedImages.length + 1, ''));
          }
          _generatedImages[index] = decodedResponse['generatedImage'];
        });

        if (index == 0) {
          // Only log template use once
          await _usedTemplateService.addUsedTemplate(_selectedTemplate!);
          await _firestoreService.incrementUseCount(
              _selectedTemplate!.id, _selectedTemplate!.author);
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Error generating image ${index + 1}: ${response.reasonPhrase}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred for image ${index + 1}.';
        });
      }
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
                      _numberOfImages = 2;
                      _images = List.generate(_numberOfImages, (_) => null);
                    } else {
                      _numberOfImages = 1;
                      _images = List.generate(1, (_) => null);
                    }
                  });
                },
              ),
            ],
          ),
          if (_isBatchPhotoshoot)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: DropdownButtonFormField<int>(
                value: _numberOfImages,
                items: List.generate(9, (i) => i + 2) // 2 to 10
                    .map((num) => DropdownMenuItem(
                          value: num,
                          child: Text('$num images'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _numberOfImages = value;
                      _images = List.generate(_numberOfImages, (_) => null);
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Number of Images',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ...List.generate(_images.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildImageUploader(index),
            );
          }),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildSectionTitle('Generation Result'),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: _generatedImages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildGeneratedImageCard(index),
              );
            },
          ),
        ),
        if (_videoController != null && _videoController!.value.isInitialized)
          _buildVideoPlayer()
        else if (_isGeneratingVideo)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Generating video...'),
              ],
            ),
          )
        else if (_generatedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.videocam_outlined),
              label: Text(widget.initialPrompt != null
                  ? 'Generate Your Reel'
                  : 'Animate First Image'),
              onPressed: (widget.initialPrompt != null)
                  ? _generateVideo
                  : _showVideoPromptDialog,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextButton.icon(
            icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
            onPressed: () => setState(() {
              _images = List.generate(
                  _isBatchPhotoshoot ? _numberOfImages : 1, (_) => null);
              _generatedImages = [];
              _videoUrl = null;
              _videoController?.dispose();
              _videoController = null;
              _isGeneratingVideo = false;
              _videoPromptController.clear();
            }),
            label: Text('Start Over',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.white70)),
          ),
        ),
      ],
    );
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
    return GlassmorphicContainer(
      width: double.infinity,
      height: 300, // Adjust height as needed
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageViewerScreen(imageBase64: _generatedImages[index]),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.memory(
                  base64Decode(_generatedImages[index]),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_outlined,
                          color: Colors.white),
                      onPressed: () => _saveImage(index),
                      tooltip: 'Download',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () => _shareImage(index),
                      tooltip: 'Share',
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate_outlined,
                          color: Colors.white),
                      onPressed: () => _addLogoToImage(index),
                      tooltip: 'Add Logo',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
