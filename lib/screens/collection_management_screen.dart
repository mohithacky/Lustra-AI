import 'package:flutter/material.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

class CollectionManagementScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const CollectionManagementScreen({
    super.key,
    required this.onboardingData,
    required this.onDataChanged,
  });

  @override
  State<CollectionManagementScreen> createState() =>
      _CollectionManagementScreenState();
}

class _CollectionManagementScreenState
    extends State<CollectionManagementScreen> {
  final List<String> _defaultCollections = [
    'Heritage',
    'Minimal',
    'Classic',
    'Luxury'
  ];

  Map<String, String> get _userCollections =>
      widget.onboardingData.userCollections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Manage Collections',
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Default Collections ---
              Text(
                'Default Collections',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF121212),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _defaultCollections.map((collection) {
                  return Chip(
                    backgroundColor: Colors.amber.withOpacity(0.15),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB5893B),
                    ),
                    label: Text(collection),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),

              // --- User Collections ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _userCollections.isEmpty
                    ? const SizedBox.shrink()
                    : Wrap(
                        key: const ValueKey('collections'),
                        spacing: 8,
                        runSpacing: 8,
                        children: _userCollections.entries.map((entry) {
                          final collectionName = entry.key;
                          final collectionData = entry.value;
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
                                Text(collectionName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF121212))),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    final newUserCollections =
                                        Map<String, String>.from(widget
                                            .onboardingData.userCollections);
                                    newUserCollections.remove(collectionName);
                                    widget.onDataChanged(widget.onboardingData
                                        .copyWith(
                                            userCollections:
                                                newUserCollections));
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
