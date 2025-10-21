import 'package:cloud_firestore/cloud_firestore.dart';

class Template {
  final String id;
  final String title;
  final String prompt;
  final String imageUrl;
  final String author;
  final int likes;
  final List<String> likedBy;
  final int useCount;
  final String jewelleryType;
  final Timestamp? createdAt;
  final int numberOfJewelleries;
  final String templateType;
  final String gender;
  final List<String> collection;
  final List<String> adTextHints;
  final bool hasMetalTypeDropdown;
  final bool hasDynamicTextFields;
  final List<String> linesList;

  const Template({
    required this.templateType,
    required this.id,
    required this.title,
    required this.prompt,
    required this.imageUrl,
    required this.author,
    required this.likes,
    this.likedBy = const [],
    this.useCount = 0,
    required this.jewelleryType,
    this.createdAt,
    this.numberOfJewelleries = 1,
    this.gender = 'men',
    this.collection = const [],
    this.adTextHints = const [],
    this.hasMetalTypeDropdown = false,
    this.hasDynamicTextFields = false,
    this.linesList = const [],
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] ?? '',
      title: json['name'] ?? '',
      prompt: json['prompt'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      author: json['author'] ?? 'Unknown',
      likes: json['likes'] ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      useCount: json['useCount'] ?? 0,
      jewelleryType: json['jewelleryType'] ?? '',
      createdAt: json['createdAt'],
      numberOfJewelleries: json['numberOfJewelleries'] ?? 1,
      templateType: json['templateType'] ?? 'Photoshoot',
      gender: json['gender'] ?? 'men',
      collection: _parseCollection(json['collection'] ?? []),
      adTextHints: List<String>.from(json['adTextHints'] ?? []),
      hasMetalTypeDropdown: json['hasMetalTypeDropdown'] ?? false,
      hasDynamicTextFields: json['hasDynamicTextFields'] ?? false,
      linesList: List<String>.from(json['linesList'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'prompt': prompt,
      'imageUrl': imageUrl,
      'jewelleryType': jewelleryType,
      'author': author,
      'likes': likes,
      'likedBy': likedBy,
      'useCount': useCount,
      'createdAt': createdAt,
      'numberOfJewelleries': numberOfJewelleries,
      'templateType': templateType,
      'gender': gender,
      'collection': collection,
      'adTextHints': adTextHints,
      'hasMetalTypeDropdown': hasMetalTypeDropdown,
      'hasDynamicTextFields': hasDynamicTextFields,
      'linesList': linesList,
    };
  }

  static List<String> _parseCollection(dynamic collectionData) {
    if (collectionData is String) {
      return [collectionData];
    } else if (collectionData is List) {
      return List<String>.from(collectionData);
    }
    return [];
  }
}
