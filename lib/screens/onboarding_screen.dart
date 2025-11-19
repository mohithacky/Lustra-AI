import 'package:flutter/material.dart';
import 'package:lustra_ai/screens/shop_details_screen.dart';
import 'package:lustra_ai/screens/category_management_screen.dart';
import 'package:lustra_ai/screens/collection_management_screen.dart';
import 'package:lustra_ai/screens/product_type_selection_screen.dart';
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

  final Map<String, String> _defaultCategories = {
    'Earrings':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fearrings.png?alt=media&token=039ba275-b8ad-4368-a676-e644d7a14714",
    'Bracelet':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fbracelet.png?alt=media&token=f56e2f20-7579-41c2-91f1-afdf43598069",
    'Pendant':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fpendant.png?alt=media&token=89e8067a-97f6-4d90-b840-348b9f8f63c1",
    'Choker':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fchoker.png?alt=media&token=6b3146df-e5d0-49ba-9ed5-f94372823152",
    'Ring':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fring.png?alt=media&token=b608cae4-1074-41c9-9faa-600fc650405f",
    'Bangles':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fbangles.png?alt=media&token=27026318-b6d7-45b0-a874-c19f5ff3b0c8",
    'Necklace':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fnecklace.png?alt=media&token=a2724d3a-0770-438d-afa2-9c80879337a3",
    'Long Necklace':
        'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Flong_necklace.png?alt=media&token=7302794e-dc33-4f81-b61e-bdb3bdfa66ed',
    'Mangtika':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fmangtika.png?alt=media&token=0ed19735-f836-41c3-a9a5-8f13642264cb",
    'Mangalsutra Pendant':
        'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fmangalsutra_pendant.png?alt=media&token=8343a491-b746-4841-b653-99c8b1ae09fc',
    'Chain':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fchain.png?alt=media&token=773911da-fba0-4213-9836-b0bab1cc702b",
    'Dholna':
        "https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fdholna.png?alt=media&token=e53076d4-64d2-425f-9b9d-0ad0436cb6ce"
  };
  final Map<String, String> _defaultCollections = {
    'Heritage':
        'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2FHeritage.jpg?alt=media&token=8413c60f-7e58-46df-8a76-fc553103bbd0',
    'Minimal':
        'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2FMinimal.jpg?alt=media&token=c67e342a-2739-4f86-8078-72b171086620',
    'Classic':
        'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2FClassic.jpg?alt=media&token=4fa4d642-70d9-4e11-ae24-1995c0ee5c33',
    'Luxury':
        'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2FLuxury.jpg?alt=media&token=78aaae67-6d65-4015-ae5d-0a968c2b50cd'
  };

  bool _isLoading = true;
  bool _isFinishing = false;
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
        final List<String> savedProductTypes =
            (details['productTypes'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                _data.productTypes;
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
          productTypes: savedProductTypes,
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
      productTypes: _data.productTypes,
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
        productTypes: _data.productTypes,
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
        productTypes: _data.productTypes,
      );
    }

    print("User Collections: ${_data.userCollections}");
    await _firestoreService.saveUserCollectionsMap(_data.userCollections);
    await _firestoreService.saveUserTheme(_data.selectedTheme);
  }

  Future<void> _finish() async {
    if (mounted) {
      setState(() {
        _isFinishing = true;
      });
    }

    try {
      await _saveOnboardingData();

      await _firestoreService.updateOnboardingStatus(true);
      await _firestoreService
          .saveInitialFooterData(_defaultCategories.keys.toList());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => const CollectionsScreen(fromOnboarding: true)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
        });
      }
    }
  }

  void _next() {
    if (_isFinishing) return;
    if (_page == 0) {
      if (!_isFirstPageValid()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please fill all shop details before continuing.')),
        );
        return;
      }
    }
    if (_page == pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isFirstPageValid() {
    final name = _data.shopName?.trim() ?? '';
    final address = _data.shopAddress?.trim() ?? '';
    final phone = _data.phoneNumber?.trim() ?? '';
    final instagram = _data.instagramId?.trim() ?? '';

    return name.isNotEmpty &&
        address.isNotEmpty &&
        phone.isNotEmpty &&
        instagram.isNotEmpty;
  }

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
      ProductTypeSelectionScreen(
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
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    children: [
                      Row(
                        children: List.generate(
                          pages.length,
                          (i) => _buildDot(i == _page),
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _isFinishing ? null : _next,
                        child: Text(isLast ? 'Get Started' : 'Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isFinishing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
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
