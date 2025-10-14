import 'package:cloud_firestore/cloud_firestore.dart';

class Reel {
  final String id;
  final String title;
  final String description;
  final String prompt;
  final String videoUrl;
  final String authorUid;
  final String? authorEmail;
  final DateTime? createdAt;

  Reel({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
    required this.videoUrl,
    required this.authorUid,
    this.authorEmail,
    this.createdAt,
  });

  factory Reel.fromMap(Map<String, dynamic> data) {
    return Reel(
      id: data['id'] as String,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      prompt: data['prompt'] as String? ?? '',
      videoUrl: data['videoUrl'] as String? ?? '',
      authorUid: data['authorUid'] as String? ?? '',
      authorEmail: data['authorEmail'] as String?,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
