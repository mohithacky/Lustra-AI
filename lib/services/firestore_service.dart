import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/screens/theme_selection_screen.dart';
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
        'coins': 100, // Initial coins for new user
        'initialCoinPopupShown': false, // Flag for the popup
        'seen_onboarding': false, // Initialize onboarding status
      });
    }
  }

  Future<bool> userExists(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<bool> isPhoneNumberTaken(String phoneNumber) async {
    final currentUser = _auth.currentUser;
    final querySnapshot = await _db
        .collection('users')
        .where('phoneNumber', isEqualTo: phoneNumber)
        .get();

    for (final doc in querySnapshot.docs) {
      if (currentUser == null || doc.id != currentUser.uid) {
        return true;
      }
    }
    return false;
  }

  Future<void> saveUserCategories(Map<String, String> categories) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'categories': categories});
  }

  Future<void> saveUserCollections(List<String> collections) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'collections': collections});
  }

  Future<void> saveUserCollectionsMap(Map<String, String> collections) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'collections': collections});
  }

  Future<void> updateUserCollectionsMap(
      String collectionName, String imageUrl) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'collections.$collectionName': imageUrl});
  }

  Future<void> saveUserTheme(WebsiteTheme theme) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'theme': theme.toString().split('.').last});
  }

  Future<void> saveBestCollections(
      List<Map<String, String>> bestCollections) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef
        .set({'best_collections': bestCollections}, SetOptions(merge: true));
  }

  Future<List<Map<String, String>>> getBestCollections() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _db.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data != null && data.containsKey('best_collections')) {
      final bestCollectionsData = data['best_collections'] as List<dynamic>;
      return bestCollectionsData.map((item) {
        final mapItem = item as Map<String, dynamic>;
        final name = mapItem['name'] as String;
        final image = mapItem['image'] as String;
        final description = (mapItem['description'] as String?) ??
            'Discover the $name collection - a curated selection of handcrafted pieces designed to blend everyday wearability with timeless elegance. Each design tells its own story, perfect for celebrating your most cherished moments.';
        return {
          'name': name,
          'image': image,
          'description': description,
        };
      }).toList();
    }
    return [];
  }

  Future<List<Map<String, String>>> getBestCollectionsfor(
      String? userId) async {
    if (userId == null) return [];

    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();

    if (data != null && data.containsKey('best_collections')) {
      final bestCollectionsData = data['best_collections'] as List<dynamic>;
      return bestCollectionsData.map((item) {
        final mapItem = item as Map<String, dynamic>;
        final name = mapItem['name'] as String;
        final image = mapItem['image'] as String;
        final description = (mapItem['description'] as String?) ??
            'Introducing our exquisite $name collection  crafted with precision, grace, and an eye for timeless beauty. Each piece reflects a unique narrative designed to elevate your finest moments with elegance that speaks louder than words.';
        return {
          'name': name,
          'image': image,
          'description': description,
        };
      }).toList();
    }
    return [];
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
  Future<void> markInitialCoinPopupAsShown() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'initialCoinPopupShown': true});
  }

  // Get current user's details
  Future<Map<String, dynamic>?> getUserDetails() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Future<Map<String, dynamic>?> getUserDetailsFor(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        return doc.data();
      } else {
        print("❌ No user found for UID: $uid");
        return null;
      }
    } catch (e) {
      print("🔥 Error in getUserDetailsFor: $e");
      return null;
    }
  }

  // Add shop details for a user
  Future<void> addShopDetails(String shopName, String shopAddress,
      String phoneNumber, String? logoUrl, String? instagramId,
      {List<String>? productTypes}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);

    return userRef.set({
      'shopName': shopName,
      'shopAddress': shopAddress,
      'phoneNumber': phoneNumber,
      if (user.email != null) 'email': user.email,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'shopDetailsFilled': true,
      if (instagramId != null) 'instagramId': instagramId,
      if (productTypes != null && productTypes.isNotEmpty)
        'productTypes': productTypes,
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

  // Get onboarding status
  Future<bool> getOnboardingStatus() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()?['seen_onboarding'] ?? false;
    }
    return false;
  }

  // Update onboarding status
  Future<void> updateOnboardingStatus(bool seen) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    await userRef.update({'seen_onboarding': seen});
  }

  Future<void> saveInitialFooterData(List<String> categoryLinks) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);
    final footerData = {
      'About': ['Our Story', 'Our Shop', 'Careers', 'Press'],
      'Shop': categoryLinks,
      'Customer Care': ['FAQs', 'Contact Us', 'Shipping & Returns', 'Warranty']
    };

    await userRef.set({'footer': footerData}, SetOptions(merge: true));
  }

  Future<Map<String, List<String>>> getFooterData(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();

    if (data != null && data.containsKey('footer')) {
      final footerData = data['footer'] as Map<String, dynamic>;
      return footerData
          .map((key, value) => MapEntry(key, List<String>.from(value)));
    }
    return {};
  }

  Future<void> updateFooterData(
      Map<String, List<String>> footerData, String userId) async {
    final userRef = _db.collection('users').doc(userId);
    await userRef.set({'footer': footerData}, SetOptions(merge: true));
  }

  // Get a real-time stream of the current user's document
  Stream<DocumentSnapshot> getUserStream() {
    final user = _auth.currentUser;
    if (user == null) {
      // Return an empty stream if the user is not logged in. The UI will not receive any data.
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).snapshots();
  }

  // Credit a specific number of coins to the current user's account
  Future<void> creditCoins(int coins) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);

    return userRef.set({
      'coins': FieldValue.increment(coins),
    }, SetOptions(merge: true));
  }

  // Deduct a specific number of coins from the current user's account
  Future<void> deductCoins(int coins) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);

    return userRef.set({
      'coins': FieldValue.increment(-coins),
    }, SetOptions(merge: true));
  }

  // Add a purchased plan to the user's history
  Future<void> updateUserPlan(Map<String, dynamic> plan) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final userRef = _db.collection('users').doc(user.uid);

    final planData = {
      'name': plan['name'],
      'coins': plan['coins'],
      'amount': plan['amount'],
      'purchasedAt':
          DateTime.now().toIso8601String(), // Use a consistent timestamp
    };

    // Atomically add the new plan to the 'purchaseHistory' array
    return userRef.update({
      'purchaseHistory': FieldValue.arrayUnion([planData]),
    });
  }

  // Upload a shop logo to Firebase Storage
  Future<String> uploadShopLogo(File image) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef = _storage.ref().child('users/${user.uid}/logo.jpg');

    final uploadTask = await storageRef.putFile(image);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  // Upload an image to Firebase Storage
  Future<String> uploadTemplateImage(File image, String templateName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef =
        _storage.ref().child('users/${user.uid}/$templateName.jpg');

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
        .then((docRef) {});
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
        .doc(
            authorEmail) // Assuming authorEmail is the UID of the template owner
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

  Future<void> updateTemplateCategory(
      Template template, String newCategory) async {
    const hardcodedUserId = 'NvxDMorN6OS4wUZMSyy9aAs1V2H3';

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
        .doc(hardcodedUserId)
        .collection('templates')
        .doc('categorized_templates')
        .collection(subcollection)
        .doc(template.id);

    await templateRef.update({'jewelleryType': newCategory});
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
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Template.fromJson(data);
    }).toList();
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
      final allDocs = [
        ...photoShootSnapshot.docs,
        ...adShootSnapshot.docs,
        ...productShootSnapshot.docs
      ];
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

  Stream<List<Template>> getTemplatesForType(String jewelleryType,
      {required String shootType}) {
    return _db
        .collectionGroup(
            shootType) // Use the shootType to query the correct collection group
        .where('jewelleryType', isEqualTo: jewelleryType)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Template.fromJson(data);
            }).toList())
        .handleError((error, stackTrace) {});
  }

  Future<Map<String, dynamic>> getUserCategories() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    final snapshot = await _db.collection('users').doc(user.uid).get();

    final Map<String, dynamic> categories = snapshot.data()!['categories'];
    return categories;
  }

  Future<Map<String, dynamic>> getUserCategoriesFor(String userId) async {
    final snapshot = await _db.collection('users').doc(userId).get();

    final Map<String, dynamic> categories = snapshot.data()!['categories'];
    return categories;
  }

  Future<Map<String, String>> getCollections({String? userId}) async {
    if (userId == null) return {};

    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();

    if (data == null || data['collections'] == null) {
      return {};
    }

    // The 'collections' field is a Map where keys are collection names and values are banner URLs.
    final collectionsData = data['collections'] as Map<String, dynamic>?;

    if (collectionsData == null) {
      return {};
    }

    // Cast the values to String
    return collectionsData.map((key, value) => MapEntry(key, value.toString()));
  }

  Future<List<Map<String, dynamic>>> getAdShootCollections() async {
    final snapshot = await _db
        .collection('adShootCollections')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Upload a category image to Firebase Storage
  Future<String> uploadProductImage(File image, String productName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef =
        _storage.ref().child('users/${user.uid}/products/$productName.jpg');

    final uploadTask = await storageRef.putFile(image);
    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  // Upload a category image to Firebase Storage
  Future<String> uploadCategoryImage(File image, String categoryName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final storageRef =
        _storage.ref().child('users/${user.uid}/categories/$categoryName.jpg');

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
        .update({'categories.$name': imageUrl});
  }

  // Get all categories for a specific user
  Future<List<Map<String, String>>> getCategories({String? userId}) async {
    String? fetchUserId = userId;
    if (fetchUserId == null) {
      final user = _auth.currentUser;
      if (user == null) return [];
      fetchUserId = user.uid;
    }

    final snapshot = await _db.collection('users').doc(fetchUserId).get();

    return snapshot.data()!['categories'].map((key, value) {
      return {'name': key, 'image': value};
    }).toList();
  }

  // Add a new product to a category
  Future<void> addProduct(
      String categoryName, Map<String, dynamic> productData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final productWithCategory = {
      ...productData,
      'category': categoryName,
    };

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .add(productWithCategory);
  }

  Future<List<Map<String, dynamic>>> getProductsForCategory(
      String categoryName) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .where('category', isEqualTo: categoryName)
        .get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getProductsForCategoryfor(
      String? userId, String categoryName) async {
    if (userId == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('category', isEqualTo: categoryName)
        .get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getProductsForCategoryforWithFilter(
      String? userId, String categoryName, String filter) async {
    if (userId == null) return [];

    Query query = _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('category', isEqualTo: categoryName);

    if (filter == 'Bestsellers') {
      query = query.where('isBestseller', isEqualTo: true);
    } else if (filter == 'Trending') {
      query = query.where('isTrending', isEqualTo: true);
    }

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getProductsForCategoryWithFilter(
      String categoryName, String filter) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    Query query = _db
        .collection('users')
        .doc(user.uid)
        .collection('products')
        .where('category', isEqualTo: categoryName);

    if (filter == 'Bestsellers') {
      query = query.where('isBestseller', isEqualTo: true);
    } else if (filter == 'Trending') {
      query = query.where('isTrending', isEqualTo: true);
    }

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  Future<List<Map<String, dynamic>>> getProductsForGender(
      String? userId, String gender) async {
    if (userId == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('gender', isEqualTo: gender)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> getProductsForCollection(
      String? userId, String collectionName) async {
    if (userId == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('collection', isEqualTo: collectionName)
        .get();

    return querySnapshot.docs.map((doc) => doc.data()).toList();
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
