import 'package:flutter/material.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/theme/app_theme.dart';

class EcommerceStudioPromptsScreen extends StatefulWidget {
  const EcommerceStudioPromptsScreen({Key? key}) : super(key: key);

  @override
  State<EcommerceStudioPromptsScreen> createState() =>
      _EcommerceStudioPromptsScreenState();
}

class _EcommerceStudioPromptsScreenState
    extends State<EcommerceStudioPromptsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _frontController = TextEditingController();
  final TextEditingController _sideController = TextEditingController();
  final TextEditingController _backController = TextEditingController();
  final TextEditingController _extraController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPrompts();
  }

  Future<void> _loadPrompts() async {
    try {
      final prompts = await _firestoreService.getEcommerceStudioPrompts();
      if (!mounted) return;
      setState(() {
        _frontController.text = prompts['front'] ?? '';
        _sideController.text = prompts['side'] ?? '';
        _backController.text = prompts['back'] ?? '';
        _extraController.text = prompts['extra'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load prompts.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _firestoreService.saveEcommerceStudioPrompts({
        'front': _frontController.text.trim(),
        'side': _sideController.text.trim(),
        'back': _backController.text.trim(),
        'extra': _extraController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ecommerce Studio prompts saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to save prompts.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _frontController.dispose();
    _sideController.dispose();
    _backController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  Widget _buildField(String label, TextEditingController controller,
      {int maxLines = 4}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ecommerce Studio Prompts'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField('Front side prompt', _frontController),
                          _buildField('Side angle prompt', _sideController),
                          _buildField('Back side prompt', _backController),
                          _buildField('Extra angle prompt', _extraController),
                          if (_errorMessage != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 8.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Prompts',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
