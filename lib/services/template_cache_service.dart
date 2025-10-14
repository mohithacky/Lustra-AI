import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/firestore_service.dart';

class TemplateCacheService {
  static final TemplateCacheService _instance = TemplateCacheService._internal();
  factory TemplateCacheService() => _instance;
  TemplateCacheService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  List<Template>? _cachedTemplates;

  Future<List<Template>> getTemplates({bool forceRefresh = false}) async {
    if (_cachedTemplates == null || forceRefresh) {
      _cachedTemplates = await _firestoreService.getAllTemplates();
    }
    return _cachedTemplates ?? [];
  }

  void clearCache() {
    _cachedTemplates = null;
  }
}
