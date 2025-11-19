import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

final FirebaseFirestore _db = FirebaseFirestore.instance;
final FirebaseStorage _storage = FirebaseStorage.instance;
final FirebaseAuth _auth = FirebaseAuth.instance;

class ProductFilters {
  // 1. Filter by category within a collection
  static Future<List<Map<String, dynamic>>> filterByCollectionCategory(
      BuildContext context,
      String collection,
      String category,
      String userId) async {
    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('collection', isEqualTo: collection)
        .where("category", isEqualTo: category)
        .get();
    // Navigate to ProductsPage with collection and category filters
    print('Filtering for category: $category in collection: $collection');
    // Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsPage(collection: collection, category: category)));
    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  // 2. Filter by category
  static Future<List<Map<String, dynamic>>> filterByCategory(
      BuildContext context, String category, String userId) async {
    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where("category", isEqualTo: category)
        .get();
    // Navigate to ProductsPage with collection and category filters
    print('Filtering for category: $category');
    // Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsPage(collection: collection, category: category)));
    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  // 3. Filter by category and gender ('Him')
  static Future<List<Map<String, dynamic>>> filterByHimCategory(
      String? userId, String gender, String category) async {
    if (userId == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('gender', isEqualTo: "Him")
        .where("category", isEqualTo: category)
        .get();
    print("Him: ${querySnapshot.docs.map((doc) => doc.data()).toList()}");

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  // 4. Filter by category and gender ('Her')
  static Future<List<Map<String, dynamic>>> filterByHerCategory(
      String? userId, String gender, String category) async {
    if (userId == null) return [];

    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('gender', isEqualTo: "Her")
        .where("category", isEqualTo: category)
        .get();
    print(querySnapshot.docs.map((doc) => doc.data()).toList());

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  // 5. Filter by product type (e.g., Gold, Diamond)
  static Future<List<Map<String, dynamic>>> filterByProductType(
      String userId, String productType) async {
    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('type', isEqualTo: productType)
        .get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }

  // 6. Filter by product type and category
  static Future<List<Map<String, dynamic>>> filterByProductTypeAndCategory(
      String userId, String productType, String category) async {
    final querySnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .where('type', isEqualTo: productType)
        .where('category', isEqualTo: category)
        .get();

    return querySnapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data() as Map<String, dynamic>,
            })
        .toList();
  }
}
