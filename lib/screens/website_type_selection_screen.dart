import 'package:flutter/material.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

class WebsiteTypeSelectionScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const WebsiteTypeSelectionScreen({
    super.key,
    required this.onboardingData,
    required this.onDataChanged,
  });

  @override
  State<WebsiteTypeSelectionScreen> createState() =>
      _WebsiteTypeSelectionScreenState();
}

class _WebsiteTypeSelectionScreenState
    extends State<WebsiteTypeSelectionScreen> {
  String? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.onboardingData.websiteType;
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
    });
    widget.onDataChanged(
      widget.onboardingData.copyWith(websiteType: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Choose Website Type',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF121212),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Select how you want your website to work. You can change this later from settings.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildTypeCard(
              label: 'Ecommerce Website',
              description:
                  'Customers can browse products and sign in with Google.',
              value: 'ecommerce',
              icon: Icons.shopping_bag_outlined,
              theme: theme,
            ),
            const SizedBox(height: 16),
            _buildTypeCard(
              label: 'Catalog Website',
              description: 'Showcase your collection like a digital catalog.',
              value: 'catalog',
              icon: Icons.collections_bookmark_outlined,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required String label,
    required String description,
    required String value,
    required IconData icon,
    required ThemeData theme,
  }) {
    final bool isSelected = _selectedType == value;

    return GestureDetector(
      onTap: () => _selectType(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFB5893B) : Colors.grey.shade300,
            width: isSelected ? 2.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF8EDD1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFB5893B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF121212),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Radio<String>(
              value: value,
              groupValue: _selectedType,
              activeColor: const Color(0xFFB5893B),
              onChanged: (_) => _selectType(value),
            ),
          ],
        ),
      ),
    );
  }
}
