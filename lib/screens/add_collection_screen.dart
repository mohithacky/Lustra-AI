import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lustra_ai/services/gemini_service.dart';

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
  final List<File> _images = [];
  File? _generatedBanner;
  String? _generatedBannerUrl;
  File? _uploadedBanner;
  bool _isGenerating = false;
  final BannerSource _bannerSource = BannerSource.generate;

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

  Future<void> _generateBanner() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isGenerating = true;
        _generatedBanner = null;
      });

      try {
        final prompt =
            "Generate a poster image for a collection named ${_collectionNameController.text} on the background I have provided in the image . This image will be shown on a ecommerce website for jewelleries. The poster should contain model. Cover the full white background.It's not compulsory that you keep the background just white.";

        // Load the asset image
        final byteData = await rootBundle.load('assets/white/16to9.avif');
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/16to9.avif');
        await file.writeAsBytes(byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

        final generatedImageBase64 =
            await GeminiService().generateImageWithUpload(prompt, [file]);

        final imageBytes = base64Decode(generatedImageBase64);

        final tempDirOut = await getTemporaryDirectory();
        final tempFile = File('${tempDirOut.path}/generated_banner.png');
        await tempFile.writeAsBytes(imageBytes);

        final bannerUrl = await _uploadBannerToStorage(tempFile);
        print('Banner URL: $bannerUrl');
        setState(() {
          _generatedBanner = tempFile;
          _generatedBannerUrl = bannerUrl;
        });
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
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        fontFamily: 'Roboto',
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.collectionType == 'AdShoot'
              ? 'Add Ad Shoot Sub-Collection'
              : 'Add New Collection'),
          backgroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSubCollection,
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
                _isGenerating
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _generateBanner,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate Banner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                if (_generatedBanner != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Generated Banner',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Image.file(
                          _generatedBanner!,
                          key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveSubCollection() async {
    final firestore = FirestoreService();
    print('Saving sub-collection...');
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a collection name.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Saving collection..."),
              ],
            ),
          ),
        );
      },
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');
      if (_generatedBannerUrl != null) {
        await firestore.updateUserCollectionsMap(
            _collectionNameController.text, _generatedBannerUrl!);
      } else {
        // Handle the case where the banner URL is not available
        throw Exception('Banner URL not available.');
      }

      Navigator.of(context).pop(); // Close the loading dialog
      Navigator.of(context)
          .pop(true); // Go back to CollectionsScreen with a result

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection added successfully!')),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close the loading dialog on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving collection: $e')),
      );
    }
  }

  Future<void> _uploadCollection() async {
    final bannerFile = _bannerSource == BannerSource.generate
        ? _generatedBanner
        : _uploadedBanner;
    if (!_formKey.currentState!.validate() || bannerFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill all fields and provide a banner.')),
      );
      return;
    }

    if (widget.collectionType == 'AdShoot' &&
        _selectedParentCollections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one parent collection.')),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in.');
      final idToken = await user.getIdToken(true);

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
        await FirebaseFirestore.instance
            .collection('adShootSubCollections')
            .add({
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
        const SnackBar(content: Text('Collection added successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading collection: $e')),
      );
    }
  }

  Future<String> _uploadBannerToStorage(File bannerFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in.');

    final storageRef = FirebaseStorage.instance.ref();
    final bannerRef = storageRef.child(
        'collections/${user.uid}/${_collectionNameController.text}/banner.png');

    await bannerRef.putFile(bannerFile);
    final downloadUrl = await bannerRef.getDownloadURL();
    return downloadUrl;
  }
}
