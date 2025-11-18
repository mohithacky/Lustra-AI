import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);
const Color kOffWhite = Color(0xFFF8F7F4);

class FooterContentScreen extends StatefulWidget {
  final String userId;
  final String title;
  final String heading;
  final String fieldKey;
  final String hintText;

  const FooterContentScreen({
    Key? key,
    required this.userId,
    required this.title,
    required this.heading,
    required this.fieldKey,
    required this.hintText,
  }) : super(key: key);

  @override
  _FooterContentScreenState createState() => _FooterContentScreenState();
}

class _FooterContentScreenState extends State<FooterContentScreen> {
  final TextEditingController _contentController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchContent() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final value = data?[widget.fieldKey] as String?;
        _contentController.text = value ?? '';
      }
    } catch (e) {
      debugPrint('Error loading footer content for ${widget.fieldKey}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveContent() async {
    if (kIsWeb) return; // safety: no saving from web
    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set(
        {
          widget.fieldKey: _contentController.text.trim(),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Content updated successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error saving footer content for ${widget.fieldKey}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdminApp = !kIsWeb; // editing only from app

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kBlack),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: kBlack,
          ),
        ),
        actions: [
          if (isAdminApp)
            IconButton(
              icon: _isEditing
                  ? (_isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, color: kBlack))
                  : const Icon(Icons.edit, color: kBlack),
              onPressed: () {
                if (!isAdminApp || _isSaving) return;
                if (_isEditing) {
                  _saveContent();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.heading,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: kBlack,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (isAdminApp && _isEditing)
                    TextFormField(
                      controller: _contentController,
                      maxLines: 16,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: GoogleFonts.lato(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: kGold, width: 1.4),
                        ),
                        filled: true,
                        fillColor: kOffWhite,
                      ),
                    )
                  else
                    Text(
                      _contentController.text.isNotEmpty
                          ? _contentController.text
                          : widget.hintText,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
