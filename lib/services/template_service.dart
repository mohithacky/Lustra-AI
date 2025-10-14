import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/firestore_service.dart';

class TemplateService {
  final CollectionReference _templatesCollection =
      FirebaseFirestore.instance.collection('templates');
  final FirestoreService _firestoreService = FirestoreService();

  Stream<List<Template>> get allTemplatesStream =>
      _templatesCollection.snapshots().map(_templateListFromSnapshot);

  Stream<List<Template>> get trendingTemplatesStream => _templatesCollection
      .orderBy('useCount', descending: true)
      .limit(10)
      .snapshots()
      .map(_templateListFromSnapshot);

  Stream<List<Template>> get recentTemplatesStream => _templatesCollection
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map(_templateListFromSnapshot);

  Future<void> toggleTemplateLike(Template template) async {
    // The author field should contain the UID of the template's creator.
    // The admin templates are fetched from a hardcoded admin UID.
    const adminUid = 'NvxDMorN6OS4wUZMSyy9aAs1V2H3';
    await _firestoreService.toggleLike(template.id, adminUid, template.templateType);
  }

  List<Template> _templateListFromSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Template.fromJson(data..['id'] = doc.id);
    }).toList();
  }

}
