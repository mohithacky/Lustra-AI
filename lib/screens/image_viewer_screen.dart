import 'dart:convert';
import 'package:flutter/material.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageBase64;

  const ImageViewerScreen({Key? key, required this.imageBase64}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            base64Decode(imageBase64),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
