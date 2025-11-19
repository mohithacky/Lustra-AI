import 'package:flutter/material.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

class CategoryManagementScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const CategoryManagementScreen({
    super.key,
    required this.onboardingData,
    required this.onDataChanged,
  });

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final List<String> _defaultCategories = [
    'Earrings',
    'Bracelet',
    'Pendant',
    'Choker',
    'Ring',
    'Bangles',
    'Necklace',
    'Long Necklace',
    'Mangtika',
    'Mangalsutra Pendant',
    'Chain',
    'Dholna',
  ];

  Map<String, String> get _userCategories =>
      widget.onboardingData.userCategories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Manage Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Color(0xFF121212),
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Default Categories ---
              Text(
                'Default Categories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF121212),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _defaultCategories.map((category) {
                  return Chip(
                    backgroundColor: Colors.amber.withOpacity(0.15),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB5893B),
                    ),
                    label: Text(category),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),

              // --- User Categories ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _userCategories.isEmpty
                    ? const SizedBox.shrink()
                    : Wrap(
                        key: const ValueKey('categories'),
                        spacing: 8,
                        runSpacing: 8,
                        children: _userCategories.entries.map((entry) {
                          final category = entry.key;
                          final categoryData = entry.value;
                          return Chip(
                            backgroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF121212))),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    final newUserCategories =
                                        Map<String, String>.from(
                                            _userCategories);
                                    newUserCategories.remove(category);
                                    widget.onDataChanged(widget.onboardingData
                                        .copyWith(
                                            userCategories: newUserCategories));
                                  },
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
