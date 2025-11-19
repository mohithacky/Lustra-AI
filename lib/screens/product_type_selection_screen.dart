import 'package:flutter/material.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

class ProductTypeSelectionScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const ProductTypeSelectionScreen({
    super.key,
    required this.onboardingData,
    required this.onDataChanged,
  });

  @override
  State<ProductTypeSelectionScreen> createState() =>
      _ProductTypeSelectionScreenState();
}

class _ProductTypeSelectionScreenState
    extends State<ProductTypeSelectionScreen> {
  final List<String> _allTypes = [
    'Gold',
    'Diamond',
    'Silver',
    'Artificial Jewellery',
  ];

  late Set<String> _selectedTypes;

  @override
  void initState() {
    super.initState();
    _selectedTypes = {...widget.onboardingData.productTypes};
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
      widget.onDataChanged(
        widget.onboardingData.copyWith(
          productTypes: _selectedTypes.toList(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Products You Sell',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF121212),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Select one or more product types that your shop sells.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allTypes.map((type) {
                final bool selected = _selectedTypes.contains(type);
                return ChoiceChip(
                  label: Text(type),
                  selected: selected,
                  selectedColor: Colors.amber.withOpacity(0.25),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFFB5893B)
                        : const Color(0xFF121212),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFFB5893B)
                          : Colors.grey.shade300,
                    ),
                  ),
                  onSelected: (_) => _toggleType(type),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
