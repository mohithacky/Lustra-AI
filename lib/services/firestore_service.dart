import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:rxdart/rxdart.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new document for a new user
  Future<void> createUserDocument({
    required User user,
    required String shopName,
    required String shopAddress,
    required String phoneNumber,
    File? shopLogo,
  }) async {
    final userRef = _db.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      String? logoUrl;
      if (shopLogo != null) {
        logoUrl = await uploadShopLogo(shopLogo);
      }

      userRef.set({
        'shopName': shopName,
        'shopAddress': shopAddress,
        'phoneNumber': phoneNumber,
        'logoUrl': logoUrl ?? '',
        'shopDetailsFilled': true, // Details are now filled at sign up
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Check if shop details are filled for a user
  Future<bool> checkShopDetailsFilled(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final doc = await userRef.get();

    if (doc.exists) {
      return doc.data()!['shopDetailsFilled'] ?? false;
    }
    return false;
  }

  // Add shop details for a user
  // Get current user's details
  Future<Map<String, dynamic>?> getUserDetails() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // Add shop details for a user
  Future<void> addShopDetails(String shopName, String shopAddress, String phoneNumber, String? logoUrl, String? productType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);

    return userRef.set({
      'shopName': shopName,
      'shopAddress': shopAddress,
      'phoneNumber': phoneNumber,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'shopDetailsFilled': true,
      if (productType != null) 'productType': productType,
    }, SetOptions(merge: true));
  }

  Future<bool> hasShopDetails() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()!['shopDetailsFilled'] ?? false;
    }
    return false;
  }

  // Upload a shop logo to Firebase Storage
  Future<String> uploadShopLogo(File image) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef = _storage
        .ref()
        .child('users/${user.uid}/logo.jpg');

    final uploadTask = await storageRef.putFile(image);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  // Upload an image to Firebase Storage
  Future<String> uploadTemplateImage(File image, String templateName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef = _storage
        .ref()
        .child('users/${user.uid}/$templateName.jpg');

    final uploadTask = await storageRef.putFile(image);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  // Add a new template to the user's collection
  Future<void> addTemplate(Template template, File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final imageUrl = await uploadTemplateImage(imageFile, template.title);

    final templateData = template.toJson();
    templateData['imageUrl'] = imageUrl;
    templateData['createdAt'] = FieldValue.serverTimestamp();

    // Determine the correct subcollection based on templateType
    String subcollection;
    switch (template.templateType.toLowerCase()) {
      case 'adshoot':
        subcollection = 'AdShoot';
        break;
      case 'productshoot':
        subcollection = 'ProductShoot';
        break;
      case 'photoshoot':
      default:
        subcollection = 'PhotoShoot';
        break;
    }

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('templates')
        .doc('categorized_templates')
        .collection(subcollection)
        .add(templateData)
        .then((docRef) {
      print('New template added at path: ${docRef.path}');
    });
  }

  // Update an existing template
  Future<void> toggleLike(
      String templateId, String authorEmail, String templateType) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');
    final userEmail = user.email!;

    // Determine the correct subcollection from templateType
    String subcollection;
    switch (templateType.toLowerCase()) {
      case 'adshoot':
        subcollection = 'AdShoot';
        break;
      case 'productshoot':
        subcollection = 'ProductShoot';
        break;
      case 'photoshoot':
      default:
        subcollection = 'PhotoShoot';
        break;
    }

    final DocumentReference docRef = _db
        .collection('users')
        .doc(authorEmail) // Assuming authorEmail is the UID of the template owner
        .collection('templates')
        .doc('categorized_templates')
        .collection(subcollection)
        .doc(templateId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) {
        throw Exception("Template does not exist in $subcollection!");
      }

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      if (likedBy.contains(userEmail)) {
        likedBy.remove(userEmail);
      } else {
        likedBy.add(userEmail);
      }

      final newLikesCount = likedBy.length;

      transaction.update(docRef, {
        'likedBy': likedBy,
        'likes': newLikesCount,
      });
    });
  }

  Future<void> incrementUseCount(String templateId, String authorEmail) async {
    final DocumentReference docRef = _db
        .collection('users')
        .doc(authorEmail)
        .collection('templates')
        .doc(templateId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("Template does not exist!");
      }
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final currentUseCount = data['useCount'] as int? ?? 0;
      final newUseCount = currentUseCount + 1;
      transaction.update(docRef, {'useCount': newUseCount});
    });
  }

  Future<void> updateTemplate(Template template, File? imageFile) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    String imageUrl = template.imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadTemplateImage(imageFile, template.title);
    }

    final templateData = template.toJson();
    templateData['imageUrl'] = imageUrl;

    // Determine the correct subcollection based on templateType
    String subcollection;
    switch (template.templateType.toLowerCase()) {
      case 'adshoot':
        subcollection = 'AdShoot';
        break;
      case 'productshoot':
        subcollection = 'ProductShoot';
        break;
      case 'photoshoot':
      default:
        subcollection = 'PhotoShoot';
        break;
    }

    final templateRef = _db
        .collection('users')
        .doc(user.uid)
        .collection('templates')
        .doc('categorized_templates')
        .collection(subcollection)
        .doc(template.id);

    await templateRef.update(templateData);
  }

  // Delete a template
  Future<void> deleteTemplate(Template template) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // First, delete the image from Firebase Storage
    if (template.imageUrl.isNotEmpty) {
      await deleteTemplateImage(template.imageUrl);
    }

    // Then, delete the template document from Firestore
    String subcollection;
    switch (template.templateType.toLowerCase()) {
      case 'adshoot':
        subcollection = 'AdShoot';
        break;
      case 'productshoot':
        subcollection = 'ProductShoot';
        break;
      case 'photoshoot':
      default:
        subcollection = 'PhotoShoot';
        break;
    }
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('templates')
        .doc('categorized_templates')
        .collection(subcollection)
        .doc(template.id)
        .delete();
  }

  // Delete an image from Firebase Storage
  Future<void> deleteTemplateImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // Log the error or handle it as needed, e.g., if the file doesn't exist
      print('Error deleting image from storage: $e');
    }
  }

  // Get all templates for the current user
  Future<List<Template>> getAllUserTemplates() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('templates')
        .get();
    return querySnapshot.docs
        .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Template.fromJson(data);
        })
        .toList();
  }


  Stream<List<Template>> getAdminTemplatesStream() {
    const hardcodedUserId = 'NvxDMorN6OS4wUZMSyy9aAs1V2H3';

    // Helper function to create a stream for a subcollection
    Stream<List<Template>> getTemplatesFromSubcollection(String subcollection) {
      return _db
          .collection('users')
          .doc(hardcodedUserId)
          .collection('templates')
          .doc('categorized_templates')
          .collection(subcollection)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return Template.fromJson(data);
              }).toList());
    }

    final photoShootStream = getTemplatesFromSubcollection('PhotoShoot');
    final adShootStream = getTemplatesFromSubcollection('AdShoot');
    final productShootStream = getTemplatesFromSubcollection('ProductShoot');

    return CombineLatestStream.combine3(
      photoShootStream,
      adShootStream,
      productShootStream,
      (List<Template> photoShoot, List<Template> adShoot,
          List<Template> productShoot) {
        // Combine all templates into a single list
        return [...photoShoot, ...adShoot, ...productShoot];
      },
    );
  }

  Stream<List<Template>> getAllUserTemplatesStream() {
    const hardcodedUserId = 'NvxDMorN6OS4wUZMSyy9aAs1V2H3';
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final photoShootStream = _db
        .collection('users')
        .doc(hardcodedUserId)
        .collection('templates')
        .doc('categorized_templates')
        .collection('PhotoShoot')
        .snapshots();
    final adShootStream = _db
        .collection('users')
        .doc(hardcodedUserId)
        .collection('templates')
        .doc('categorized_templates')
        .collection('AdShoot')
        .snapshots();
    final productShootStream = _db
        .collection('users')
        .doc(hardcodedUserId)
        .collection('templates')
        .doc('categorized_templates')
        .collection('ProductShoot')
        .snapshots();

    return photoShootStream.asyncMap((photoShootSnapshot) async {
      final adShootSnapshot = await adShootStream.first;
      final productShootSnapshot = await productShootStream.first;
      final allDocs = [...photoShootSnapshot.docs, ...adShootSnapshot.docs, ...productShootSnapshot.docs];
      return allDocs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Template.fromJson(data);
      }).toList();
    });
  }

  Future<List<Template>> getAllTemplates() async {
    final querySnapshot = await _db.collectionGroup('templates').get();
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Template.fromJson(data);
    }).toList();
  }

    Stream<List<Template>> getTemplatesForType(String jewelleryType, {required String shootType}) {
    return _db
        .collectionGroup(shootType) // Use the shootType to query the correct collection group
        .where('jewelleryType', isEqualTo: jewelleryType)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Template.fromJson(data);
            }).toList())
        .handleError((error, stackTrace) {
      print('❌ [FirestoreService] ERROR fetching templates for type: $jewelleryType and shootType: $shootType');
      print('❌ ERROR: $error');
      print('❌ StackTrace: $stackTrace');
    });
  }

  Future<List<Map<String, dynamic>>> getCollections({String? userId}) async {
    String? fetchUserId = userId;
    if (fetchUserId == null) {
      final user = _auth.currentUser;
      if (user == null) return [];
      fetchUserId = user.uid;
    }

    final snapshot = await _db
        .collection('users')
        .doc(fetchUserId)
        .collection('collections')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Upload a category image to Firebase Storage
  Future<String> uploadCategoryImage(File image, String categoryName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef = _storage
        .ref()
        .child('users/${user.uid}/categories/$categoryName.jpg');

    final uploadTask = await storageRef.putFile(image);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  // Add a new category to the user's collection
  Future<void> addCategory(String name, String imageUrl) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .add({'name': name, 'image': imageUrl, 'createdAt': FieldValue.serverTimestamp()});
  }

  // Get all categories for a specific user
  Future<List<Map<String, String>>> getCategories({String? userId}) async {
    String? fetchUserId = userId;
    if (fetchUserId == null) {
      final user = _auth.currentUser;
      if (user == null) return [];
      fetchUserId = user.uid;
    }

    final snapshot = await _db
        .collection('users')
        .doc(fetchUserId)
        .collection('categories')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {'name': data['name'] as String, 'image': data['image'] as String};
    }).toList();
  }
}

extension ReelsApi on FirestoreService {
  // Upload a reel video to Firebase Storage and return its download URL
  Future<String> uploadReelVideo(File video, String fileName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final ref = _storage.ref().child('reels/${user.uid}/$fileName.mp4');
    final uploadTask = await ref.putFile(video);
    return await uploadTask.ref.getDownloadURL();
  }

  // Create a new reel document in a public 'reels' collection
  Future<void> addReel({
    required String title,
    String? description,
    required String prompt,
    required File videoFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final videoUrl = await uploadReelVideo(
        videoFile, '${DateTime.now().millisecondsSinceEpoch}_$title');

    await _db.collection('reels').add({
      'title': title,
      'description': description ?? '',
      'prompt': prompt,
      'videoUrl': videoUrl,
      'authorUid': user.uid,
      'authorEmail': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Public stream of reels ordered by createdAt desc
  Stream<List<Map<String, dynamic>>> getReelsStream() {
    return _db
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }
}
