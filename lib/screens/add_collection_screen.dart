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

enum BannerSource { generate, upload }

class AddCollectionScreen extends StatefulWidget {
  const AddCollectionScreen({Key? key}) : super(key: key);

  @override
  _AddCollectionScreenState createState() => _AddCollectionScreenState();
}

class _AddCollectionScreenState extends State<AddCollectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _collectionNameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  bool _addImage = false;
  final List<File> _images = [];
  File? _generatedBanner;
  File? _uploadedBanner;
  bool _isGenerating = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  BannerSource _bannerSource = BannerSource.generate;

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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
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

        final url = Uri.parse(
            'https://central-miserably-sunbird.ngrok-free.app/upload');
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
        title: const Text('Add New Collection'),
        backgroundColor: AppTheme.secondaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // TODO: Implement save logic
                print('Collection Name: ${_collectionNameController.text}');
                print('Selected Color: $_selectedColor');
                print('Add Image: $_addImage');
                print('Images: ${_images.length}');
                Navigator.of(context).pop();
              }
            },
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
                decoration: const InputDecoration(
                  labelText: 'Collection Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a collection name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              Text('Banner Source', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<BannerSource>(
                segments: const [
                  ButtonSegment(value: BannerSource.generate, label: Text('Generate AI Banner')),
                  ButtonSegment(value: BannerSource.upload, label: Text('Upload Banner')),
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
                title: const Text('Add Images'),
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
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              _images.length + 1, // +1 for the add button
                          itemBuilder: (context, index) {
                            if (index == _images.length) {
                              return GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.grey[400]!)),
                                  child: const Icon(Icons.add_a_photo,
                                      color: Colors.grey, size: 40),
                                ),
                              );
                            }
                            return Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(_images[index]),
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
                      const SizedBox(height: 24),
                      if (_bannerSource == BannerSource.generate && _images.isNotEmpty)
                        _isGenerating
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _generateBanner,
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Generate Banner'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                                style: Theme.of(context).textTheme.titleMedium,
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
          ),
        ),
      ),
    );
  }

  Future<void> _uploadCollection() async {
    final bannerFile = _bannerSource == BannerSource.generate ? _generatedBanner : _uploadedBanner;
    if (_formKey.currentState!.validate() && bannerFile != null) {
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

        // Print the Firebase Storage URL of the banner
        print('\n==== UPLOADED BANNER URL ====');
        print('Firebase URL: $bannerUrl');
        print('==============================\n');

        // 2. Upload Product Images
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Collection added to website successfully!')),
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
}
