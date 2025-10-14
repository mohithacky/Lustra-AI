import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';

class AddReelScreen extends StatefulWidget {
  const AddReelScreen({super.key});

  @override
  State<AddReelScreen> createState() => _AddReelScreenState();
}

class _AddReelScreenState extends State<AddReelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _promptController = TextEditingController();
  final _picker = ImagePicker();
  File? _videoFile;
  bool _isSubmitting = false;

  bool get _isAdmin => FirebaseAuth.instance.currentUser?.email == 'mohithacky890@gmail.com';

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _videoFile = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can add reels.')),
      );
      return;
    }
    if (!_formKey.currentState!.validate() || _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the form and select a video.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await FirestoreService().addReel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        prompt: _promptController.text.trim(),
        videoFile: _videoFile!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reel added successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add reel: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add AdShoot Reel'),
      ),
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _promptController,
                  decoration: const InputDecoration(labelText: 'Prompt'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Prompt is required' : null,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.video_library),
                      label: const Text('Pick Video'),
                    ),
                    const SizedBox(width: 12),
                    if (_videoFile != null)
                      Expanded(
                        child: Text(
                          _videoFile!.path.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(_isSubmitting ? 'Uploading...' : 'Upload Reel'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
