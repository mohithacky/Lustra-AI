import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lustra_ai/services/backend_config.dart';

enum BannerSource { generate, upload }

class AddCollectionScreen extends StatefulWidget {
  final String collectionType;

  const AddCollectionScreen({Key? key, this.collectionType = 'default'})
      : super(key: key);

  @override
  _AddCollectionScreenState createState() => _AddCollectionScreenState();
}

class _AddCollectionScreenState extends State<AddCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _collectionNameController = TextEditingController();

  // For 'AdShoot' type
  final List<String> _parentCollections = [
    'Festive',
    'Luxury',
    'Minimal',
    'Trending'
  ];
  final List<String> _selectedParentCollections = [];

  // For 'default' type
  Color _selectedColor = Colors.blue;
  final List<Color> _colorPalette = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  // Common state
  bool _addImage = false;
  final List<File> _images = [];
  File? _generatedBanner;
  File? _uploadedBanner;
  bool _isGenerating = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  BannerSource _bannerSource = BannerSource.generate;

  @override
  void initState() {
    super.initState();
    _selectedColor = _colorPalette.first;
    _generatedBanner = null;
    _uploadedBanner = null;
  }

  @override
  void dispose() {
    _collectionNameController.dispose();
    super.dispose();
  }

  Future<void> _pickMultipleImages() async {
    final List<XFile> pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        for (var file in pickedFiles) {
          _images.add(File(file.path));
        }
      });
    }
  }

  Future<void> _pickBanner() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _uploadedBanner = File(pickedFile.path);
      });
    }
  }

  Future<void> _generateBanner() async {
    if (_formKey.currentState!.validate() && _images.isNotEmpty) {
      // Clear any existing banner file
      if (_generatedBanner != null) {
        try {
          if (await _generatedBanner!.exists()) {
            await _generatedBanner!.delete();
          }
        } catch (e) {
          print('Error deleting previous banner: $e');
        }
      }

      setState(() {
        _isGenerating = true;
        _generatedBanner = null;
      });

      try {
        final prompt =
            '''Generate a jewellery banner for the collection name: "${_collectionNameController.text}", using the uploaded jewellery images and models. 
generated Banner size aspect ratio should be 16:5.
The entire frame must be naturally filled with models and jewellery, well-composed as a banner. 
strictly size of generated banner should be in ratio 16:5. ''';

        // Print the prompt to the console when button is clicked
        print('\n==== BANNER GENERATION PROMPT ====');
        print(prompt);
        print('================================\n');

        final url = Uri.parse('$backendBaseUrl/upload');
        final request = http.MultipartRequest('POST', url);

        request.fields['prompt'] = prompt;

        for (int i = 0; i < _images.length; i++) {
          request.files.add(
              await http.MultipartFile.fromPath('image_$i', _images[i].path));
        }

        final response = await request.send();

        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          final decodedResponse = json.decode(responseBody);
          final imageBase64 = decodedResponse['generatedImage'];
          final imageBytes = base64Decode(imageBase64);

          final tempDir = await getTemporaryDirectory();
          // Use a unique timestamp to create a new file path each time
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final tempFile =
              File('${tempDir.path}/generated_banner_$timestamp.png');
          await tempFile.writeAsBytes(imageBytes);

          setState(() {
            _generatedBanner = tempFile;
          });

          // Print the file path of the generated banner to the console
          print('\n==== GENERATED BANNER LOCATION ====');
          print('File path: ${tempFile.path}');
          print('================================\n');
        } else {
          throw Exception(
              'Failed to generate banner: ${response.reasonPhrase}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating banner: $e')),
        );
      } finally {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectionType == 'AdShoot'
            ? 'Add Ad Shoot Sub-Collection'
            : 'Add New Collection'),
        backgroundColor: AppTheme.secondaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: widget.collectionType == 'AdShoot'
                ? _saveSubCollection
                : _uploadCollection,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _collectionNameController,
                decoration: InputDecoration(
                  labelText: widget.collectionType == 'AdShoot'
                      ? 'Sub-Collection Name'
                      : 'Collection Name',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (widget.collectionType == 'AdShoot')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parent Collections',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: _parentCollections.map((collection) {
                        return ChoiceChip(
                          label: Text(collection),
                          selected: _selectedParentCollections.contains(collection),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedParentCollections.add(collection);
                              } else {
                                _selectedParentCollections.remove(collection);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Collection Banner Theme',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: GridView.builder(
                        scrollDirection: Axis.horizontal,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _colorPalette.length,
                        itemBuilder: (context, index) {
                          final color = _colorPalette[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: _selectedColor == color
                                      ? Border.all(color: Colors.white, width: 3)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              if (widget.collectionType != 'AdShoot') ...[
                const SizedBox(height: 24),
                Text('Banner Source',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<BannerSource>(
                  segments: const [
                    ButtonSegment(
                        value: BannerSource.generate,
                        label: Text('Generate AI Banner')),
                    ButtonSegment(
                        value: BannerSource.upload, label: Text('Upload Banner')),
                  ],
                  selected: {_bannerSource},
                  onSelectionChanged: (Set<BannerSource> newSelection) {
                    setState(() {
                      _bannerSource = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text('Add Images for Banner Generation'),
                  value: _addImage,
                  onChanged: (bool value) {
                    setState(() {
                      _addImage = value;
                    });
                  },
                  secondary: const Icon(Icons.image),
                ),
                if (_addImage)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Collection Images',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
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
                                          image: FileImage(_images[index]),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle, color: Colors.red),
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
                        const SizedBox(height: 24),
                        if (_bannerSource == BannerSource.generate &&
                            _images.isNotEmpty)
                          _isGenerating
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _generateBanner,
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Generate Banner'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                ),
                        if (_bannerSource == BannerSource.upload)
                          ElevatedButton.icon(
                            onPressed: _pickBanner,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Banner Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        if (_generatedBanner != null || _uploadedBanner != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _bannerSource == BannerSource.generate
                                      ? 'Generated Banner'
                                      : 'Uploaded Banner',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Image.file(
                                  _bannerSource == BannerSource.generate
                                      ? _generatedBanner!
                                      : _uploadedBanner!,
                                  key: ValueKey(
                                      DateTime.now().millisecondsSinceEpoch),
                                ),
                                const SizedBox(height: 16),
                                _isUploading
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : ElevatedButton.icon(
                                        onPressed: _uploadCollection,
                                        icon: const Icon(
                                            Icons.add_to_photos_outlined),
                                        label: const Text('Add to Website'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSubCollection() async {
    if (!_formKey.currentState!.validate() || _selectedParentCollections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a name and select at least one parent collection.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await FirebaseFirestore.instance.collection('adShootSubCollections').add({
        'name': _collectionNameController.text,
        'parentCollections': _selectedParentCollections,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub-collection added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sub-collection: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadCollection() async {
    final bannerFile = _bannerSource == BannerSource.generate
        ? _generatedBanner
        : _uploadedBanner;
    if (!_formKey.currentState!.validate() || bannerFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and provide a banner.')),
      );
      return;
    }

    if (widget.collectionType == 'AdShoot' && _selectedParentCollections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one parent collection.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');

      final collectionName = _collectionNameController.text;
      final storageRef = FirebaseStorage.instance.ref();

      // 1. Upload Banner Image
      final bannerRef = storageRef
          .child('collections/${user.uid}/$collectionName/banner.png');
      await bannerRef.putFile(bannerFile);
      final bannerUrl = await bannerRef.getDownloadURL();

      print('\n==== UPLOADED BANNER URL ====');
      print('Firebase URL: $bannerUrl');
      print('==============================\n');

      // 2. Upload Product Images (if any)
      final List<String> productUrls = [];
      for (int i = 0; i < _images.length; i++) {
        final imageFile = _images[i];
        final productRef = storageRef
            .child('collections/${user.uid}/$collectionName/product_$i.png');
        await productRef.putFile(imageFile);
        final productUrl = await productRef.getDownloadURL();
        productUrls.add(productUrl);
      }

      // 3. Save to Firestore
      if (widget.collectionType == 'AdShoot') {
        await FirebaseFirestore.instance.collection('adShootSubCollections').add({
          'name': collectionName,
          'bannerUrl': bannerUrl,
          'parentCollections': _selectedParentCollections,
          'createdAt': Timestamp.now(),
        });
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('collections')
            .add({
          'name': collectionName,
          'bannerUrl': bannerUrl,
          'productImageUrls': productUrls,
          'themeColor': _selectedColor.value,
          'createdAt': Timestamp.now(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Collection added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading collection: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
