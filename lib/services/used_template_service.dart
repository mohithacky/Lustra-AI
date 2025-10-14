import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/models/template.dart';

class UsedTemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addUsedTemplate(Template template) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usedTemplates')
        .doc(template.id);

    await docRef.set(template.toJson());
  }

  Future<List<Template>> getUsedTemplates() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usedTemplates')
        .get();

    return querySnapshot.docs
        .map((doc) => Template.fromJson(doc.data()))
        .toList();
  }

  Stream<List<Template>> getUsedTemplatesStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('usedTemplates')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Template.fromJson(doc.data()))
            .toList());
  }
}
