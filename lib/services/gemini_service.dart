import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class GeminiService {
  final String _baseUrl = 'https://central-miserably-sunbird.ngrok-free.app';

  Future<String> generateAdShootImageWithoutImage(String prompt) async {
    final url = Uri.parse('$_baseUrl/upload_without_image');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt}),
    );

    if (response.statusCode == 200) {
      final decodedResponse = jsonDecode(response.body);
      return decodedResponse['generatedImage'];
    } else {
      throw Exception('Failed to generate image: ${response.reasonPhrase} - ${response.body}');
    }
  }

  Future<String> generateImageWithUpload(String prompt, File image) async {
    final url = Uri.parse('$_baseUrl/upload');
    var request = http.MultipartRequest('POST', url);

    request.fields['prompt'] = prompt;

    request.files.add(await http.MultipartFile.fromPath(
      'image_0',
      image.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    var response = await request.send();

    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final decodedResponse = jsonDecode(responseBody);
      return decodedResponse['generatedImage'];
    } else {
      final errorBody = await response.stream.bytesToString();
      throw Exception(
          'Failed to generate image: ${response.reasonPhrase} - $errorBody');
    }
  }
}
