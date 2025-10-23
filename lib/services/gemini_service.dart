import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:lustra_ai/services/backend_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeminiService {
  final String _baseUrl = backendBaseUrl;

  Future<String> generateAdShootImageWithoutImage(String prompt) async {
    final url = Uri.parse('$_baseUrl/upload_without_image');
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        return decodedResponse['generatedImage'];
      } else {
        print('UPLOAD_WITHOUT_IMAGE_ERROR status: ${response.statusCode}, reason: ${response.reasonPhrase}, body: ${response.body}');
        throw Exception('Failed to generate image: ${response.reasonPhrase} - ${response.body}');
      }
    } catch (e) {
      print('UPLOAD_WITHOUT_IMAGE_EXCEPTION: $e');
      rethrow;
    }
  }

  Future<String> generateImageWithUpload(String prompt, List<File> images) async {
    final url = Uri.parse('$_baseUrl/upload');
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);

    List<String> base64Images = [];
    for (var image in images) {
      List<int> imageBytes = await image.readAsBytes();
      base64Images.add(base64Encode(imageBytes));
    }

    final body = jsonEncode({
      'prompt': prompt,
      'imgBase64': base64Images,
      'mimeType': 'image/jpeg',
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        return decodedResponse['generatedImage'];
      } else {
        print('UPLOAD_ERROR status: ${response.statusCode}, reason: ${response.reasonPhrase}, body: ${response.body}');
        throw Exception('Failed to generate image: ${response.reasonPhrase} - ${response.body}');
      }
    } catch (e) {
      print('UPLOAD_EXCEPTION: $e');
      rethrow;
    }
  }
}
