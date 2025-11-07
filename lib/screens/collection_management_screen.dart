import 'package:flutter/material.dart';
import 'package:lustra_ai/models/onboarding_data.dart';

class CollectionManagementScreen extends StatefulWidget {
  final OnboardingData onboardingData;
  final Function(OnboardingData) onDataChanged;

  const CollectionManagementScreen({super.key, 
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

  List<String> get _userCollections => widget.onboardingData.userCollections;

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
              Row(
                children: [
                  Text(
                    'Your Collections',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF121212),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _userCollections.isEmpty
                    ? Container(
                        key: const ValueKey('empty'),
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'No custom collections yet.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Wrap(
                        key: const ValueKey('collections'),
                        spacing: 8,
                        runSpacing: 8,
                        children: _userCollections.map((collection) {
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
                                Text(collection,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF121212))),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () {
                                    final newUserCollections = List<String>.from(widget.onboardingData.userCollections);
                                    newUserCollections.remove(collection);
                                    widget.onDataChanged(widget.onboardingData.copyWith(userCollections: newUserCollections));
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
