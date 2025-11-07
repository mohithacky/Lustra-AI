import 'package:flutter/material.dart';
import 'package:lustra_ai/screens/shop_details_screen.dart';
import 'package:lustra_ai/screens/category_management_screen.dart';
import 'package:lustra_ai/screens/collection_management_screen.dart';
import 'package:lustra_ai/screens/theme_selection_screen.dart';
import 'package:lustra_ai/models/onboarding_data.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/screens/collections_screen.dart';

class OnboardingApp extends StatelessWidget {
  const OnboardingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Onboarding Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.amber,
        fontFamily: 'Roboto',
      ),
      home: const LaunchDecider(),
    );
  }
}

/// Decides whether to show onboarding or home based on saved flag.
class LaunchDecider extends StatefulWidget {
  const LaunchDecider({super.key});

  @override
  State<LaunchDecider> createState() => _LaunchDeciderState();
}

class _LaunchDeciderState extends State<LaunchDecider> {
  final FirestoreService _firestoreService = FirestoreService();
  Future<bool>? _seenFuture;

  @override
  void initState() {
    super.initState();
    _seenFuture = _firestoreService.getOnboardingStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _seenFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final seen = snap.data!;
        return seen ? const HomePage() : const OnboardingScreen();
      },
    );
  }
}

/// Simple data model for each onboarding page.
class OnboardPageData {
  final IconData icon;
  final String title;
  final String subtitle;

  const OnboardPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  late OnboardingData _data;
  final FirestoreService _firestoreService = FirestoreService();

  final List<String> _defaultCategories = [
    'All',
    'Earrings',
    'Bracelet',
    'Pendant',
    'Choker',
    'Ring',
    'Bangles',
    'Necklace',
    'Long\nNecklace',
    'Mangtika',
    'Mangalsutra\nPendant',
    'Chain',
    'Dholna'
  ];
  final List<String> _defaultCollections = [
    'Heritage',
    'Minimal',
    'Classic',
    'Luxury'
  ];

  bool _isLoading = true;
  List<Widget> pages = [];

  @override
  void initState() {
    super.initState();
    _data = OnboardingData(); // Initialize with empty data
    _fetchShopDetails();
  }

  Future<void> _fetchShopDetails() async {
    final details = await _firestoreService.getUserDetails();
    if (details != null) {
      // Create a new instance of OnboardingData to trigger a state change
      setState(() {
        _data = OnboardingData(
          shopName: details['shopName'],
          shopAddress: details['shopAddress'],
          phoneNumber: details['phoneNumber'],
          instagramId: details['instagramId'],
          // Preserve other data if necessary
          logoFile: _data.logoFile,
          userCategories: _data.userCategories,
          userCollections: _data.userCollections,
          selectedTheme: _data.selectedTheme,
        );
      });
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveOnboardingData() async {
    String? logoUrl;
    if (_data.logoFile != null) {
      logoUrl = await _firestoreService.uploadShopLogo(_data.logoFile!);
    }

    await _firestoreService.addShopDetails(
      _data.shopName ?? '',
      _data.shopAddress ?? '',
      _data.phoneNumber ?? '',
      logoUrl,
      _data.instagramId,
    );

    if (_data.userCategories.isEmpty) {
      _data = OnboardingData(
        shopName: _data.shopName,
        shopAddress: _data.shopAddress,
        phoneNumber: _data.phoneNumber,
        instagramId: _data.instagramId,
        logoFile: _data.logoFile,
        userCategories: _defaultCategories,
        userCollections: _data.userCollections,
        selectedTheme: _data.selectedTheme,
      );
    }
    await _firestoreService.saveUserCategories(_data.userCategories);

    if (_data.userCollections.isEmpty) {
      _data = OnboardingData(
        shopName: _data.shopName,
        shopAddress: _data.shopAddress,
        phoneNumber: _data.phoneNumber,
        instagramId: _data.instagramId,
        logoFile: _data.logoFile,
        userCategories: _data.userCategories,
        userCollections: _defaultCollections,
        selectedTheme: _data.selectedTheme,
      );
    }
    await _firestoreService.saveUserCollections(_data.userCollections);
    await _firestoreService.saveUserTheme(_data.selectedTheme);
  }

  Future<void> _finish() async {
    await _saveOnboardingData();

    await _firestoreService.updateOnboardingStatus(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => const CollectionsScreen(fromOnboarding: true)),
    );
  }

  void _next() {
    if (_page == pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _skip() => _finish();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: active ? 20 : 8,
      decoration: BoxDecoration(
        color: active ? Colors.amber : Colors.amber.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    pages = [
      ShopDetailsScreen(
        onboardingData: _data,
        onDataChanged: (newData) => setState(() => _data = newData),
      ),
      CategoryManagementScreen(
        onboardingData: _data,
        onDataChanged: (newData) => setState(() => _data = newData),
      ),
      CollectionManagementScreen(
        onboardingData: _data,
        onDataChanged: (newData) => setState(() => _data = newData),
      ),
      ThemeSelectionScreen(
        onboardingData: _data,
        onDataChanged: (newData) => setState(() => _data = newData),
      ),
    ];

    final isLast = _page == pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: Skip
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: _skip, child: const Text('Skip')),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, index) {
                  final p = pages[index];
                  return p;
                },
              ),
            ),

            // Dots + Next/Get Started
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  // dots
                  Row(
                    children: List.generate(
                      pages.length,
                      (i) => _buildDot(i == _page),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: _next,
                    child: Text(isLast ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _resetOnboarding(BuildContext context) async {
    final FirestoreService firestoreService = FirestoreService();
    await firestoreService.updateOnboardingStatus(false);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Onboarding reset. Please restart the app.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lustra AI')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome to Lustra AI!'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const OnboardingApp()),
                );
              },
              child: const Text('Set Up Shop'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _resetOnboarding(context),
              child: const Text('Reset onboarding (for testing)'),
            ),
          ],
        ),
      ),
    );
  }
}
