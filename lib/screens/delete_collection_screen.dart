import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DeleteCollectionScreen extends StatefulWidget {
  const DeleteCollectionScreen({Key? key}) : super(key: key);

  @override
  _DeleteCollectionScreenState createState() => _DeleteCollectionScreenState();
}

class _DeleteCollectionScreenState extends State<DeleteCollectionScreen> {
  @override
  void initState() {
    super.initState();
    print('[DeleteCollectionScreen] Initialized');
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _didDelete = false;

  Future<void> _deleteCollection(String collectionName) async {
    print('[DeleteCollectionScreen] Attempting to delete collection: $collectionName');
    final user = _auth.currentUser;
    if (user == null) return;

    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text('Are you sure you want to delete the "$collectionName" collection? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Remove the collection from the map in the user's document
      await _firestore.collection('users').doc(user.uid).update({
        'collections.$collectionName': FieldValue.delete(),
      });

      // Attempt to delete the associated banner from Storage
      try {
        final bannerRef = _storage.ref('collections/${user.uid}/$collectionName/banner.png');
        await bannerRef.delete();
      } catch (e) {
        print('Could not delete banner for $collectionName: $e');
      }

      setState(() {
        _didDelete = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting collection: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_didDelete);
        return true;
      },
      child: Theme(
        data: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.amber,
          fontFamily: 'Roboto',
        ),
        child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Collections'),
        ),
        body: user == null
            ? const Center(child: Text('Please log in to see your collections.'))
            : StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text('No collections found.'));
                  }

                  print('[DeleteCollectionScreen] StreamBuilder connection state: ${snapshot.connectionState}');
                  if (snapshot.hasError) {
                    print('[DeleteCollectionScreen] StreamBuilder error: ${snapshot.error}');
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  final collectionsMap = userData?['collections'] as Map<String, dynamic>? ?? {};
                  final collections = collectionsMap.keys.toList();
                  print('[DeleteCollectionScreen] Found collections: $collections');

                  if (collections.isEmpty) {
                    return const Center(child: Text('No collections found.'));
                  }

                  return ListView.builder(
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collectionName = collections[index];
                      return ListTile(
                        title: Text(collectionName),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCollection(collectionName),
                        ),
                      );
                    },
                  );
                },
              ),
      ),), // Closing parenthesis for Theme
    );
  }
}
