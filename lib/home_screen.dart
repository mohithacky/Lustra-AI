import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/screens/payment_webview_screen.dart';
import 'package:lustra_ai/services/auth_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/widgets/static_template_grid.dart';
import 'package:lustra_ai/widgets/circular_category_carousel.dart';
import 'package:lustra_ai/widgets/collections_carousel.dart';
import 'package:lustra_ai/screens/login_screen.dart';
import 'package:lustra_ai/screens/shop_details_screen.dart';
import 'package:lustra_ai/screens/add_reel_screen.dart';
import 'package:lustra_ai/screens/add_template_screen.dart';
import 'package:lustra_ai/screens/collections_screen.dart';
import 'package:lustra_ai/screens/my_designs_screen.dart';
import 'package:lustra_ai/screens/used_templates_screen.dart';
import 'package:lustra_ai/screens/reels_screen.dart';
import 'package:lustra_ai/screens/add_template_options_screen.dart';
import 'package:lustra_ai/services/connectivity_service.dart';
import 'package:lustra_ai/widgets/offline_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;
  bool _showBackToTopButton = false;
  int _bottomNavIndex = 0;
  final AuthService _auth = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  List<Template> _allAdminTemplates = [];
  String? _selectedCategory;
  String _selectedGender = 'men';
  String? _selectedCollection;
  List<Map<String, dynamic>> _adShootCollections = [];
  List<Map<String, dynamic>> _adShootSubCollections = [];
  String? _selectedSubCollection;
  bool _showGenderSwitch = true;
  bool _showCollectionsCarousel = true;
  bool _showCategoryCarousel = true;
  bool _isLoggingOut = false;

  // 🎨 Softer gold + matte black tones
  final Color _softGold = const Color(0xFFE3C887);
  final Color _matteBlack = const Color(0xFF121212);
  final Color _darkGrey = const Color(0xFF1A1A1A);
  final Color _lightText = Colors.white70;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {
            // Reset filters when tab changes for a clean state
            _selectedCollection = null;
            _selectedSubCollection = null;
            _adShootSubCollections = [];

            _showGenderSwitch = _tabController.index != 2;
            _showCategoryCarousel =
                _tabController.index != 2; // Collapse categories on AdShoot
            _showCollectionsCarousel = true; // Always show collections
          });
        }
      });
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _showBackToTopButton = _scrollController.offset >= 300;
        });
      });

    final Stream<List<Template>> templatesStream =
        _firestoreService.getAdminTemplatesStream();

    templatesStream.listen((templates) {
      if (mounted) setState(() => _allAdminTemplates = templates);
    });

    _fetchAdShootCollections();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var category in _getCategoryList()) {
        precacheImage(AssetImage(category['image']!), context);
      }
      for (var collection in _getCollectionList()) {
        precacheImage(AssetImage(collection['image']!), context);
      }
    });
  }

  void _onItemTapped(int index) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == 'mohithacky890@gmail.com';

    if (index == 1 && !isAdmin) {
      _navigateToCollections();
    } else {
      setState(() => _bottomNavIndex = index);
    }
  }

  void _navigateToCollections() async {
    bool hasDetails = await _firestoreService.hasShopDetails();
    if (mounted) {
      if (hasDetails) {
        setState(() => _bottomNavIndex = 1);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ShopDetailsScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bool isAdmin = user?.email == 'mohithacky890@gmail.com';

    return Scaffold(
      backgroundColor: _matteBlack,
      body: _buildPage(_bottomNavIndex, isAdmin),
      floatingActionButton: _buildFloatingActionButton(isAdmin),
      floatingActionButtonLocation: _showBackToTopButton
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(isAdmin),
    );
  }

  Widget _buildBottomBar(bool isAdmin) {
    return BottomAppBar(
      color: _darkGrey,
      shape: isAdmin ? const CircularNotchedRectangle() : null,
      notchMargin: isAdmin ? 8.0 : 0.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _navItem(Icons.home_outlined, 'Home', 0),
          if (isAdmin) const SizedBox(width: 48),
          _navItem(Icons.history_outlined, 'Used', 2),
          _navItem(Icons.credit_card_outlined, 'Pay', 3),
          _navItem(Icons.person_outline, 'Profile', 4),
          _navItem(Icons.play_circle_outline, 'Reels', 5),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final bool isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? _softGold : Colors.white54, size: 26),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? _softGold : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAdShootCollections() async {
    final collections = await _firestoreService.getAdShootCollections();
    if (mounted) {
      setState(() {
        _adShootCollections = collections;
      });
    }
  }

  Future<void> _fetchAdShootSubCollections(String parentCollection) async {
    final subCollections =
        await _firestoreService.getAdShootSubCollections(parentCollection);
    if (mounted) {
      setState(() {
        _adShootSubCollections = subCollections;
        _selectedSubCollection = null; // Reset sub-collection selection
      });
    }
  }

  Widget _buildHomeScreenBody() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return SafeArea(
      child: CustomScrollView(
        controller: _scrollController,
        physics: isPortrait
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const CircleAvatar(
                    backgroundImage: AssetImage("assets/images/logo.png"),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFF8EAC2),
                        Color(0xFFE2C06D),
                        Color(0xFFF4E7C0),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      "LUSTRA AI",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestoreService.getUserStream(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final coins = userData?['coins'] ?? 0;
                          return Chip(
                            avatar: Icon(Icons.monetization_on,
                                color: _softGold, size: 18),
                            label: Text(
                              '$coins',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: _darkGrey,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          );
                        },
                      ),
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isLoggingOut)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white70),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.logout,
                                    color: Colors.white70),
                                onPressed: () async {
                                  if (!await ConnectivityService
                                      .isConnected()) {
                                    if (mounted) showOfflineDialog(context);
                                    return;
                                  }
                                  setState(() => _isLoggingOut = true);
                                  try {
                                    await _auth.signOut();
                                    if (mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginScreen()),
                                        (route) => false,
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Logout Failed'),
                                          content: const Text(
                                              'An unexpected error occurred...'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      setState(() => _isLoggingOut = false);
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: _showCategoryCarousel ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showCategoryCarousel ? 120 : 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: CircularCategoryCarousel(
                    categories: _getCategoryList()
                        .where((c) => c['name'] != 'All')
                        .toList(),
                    onCategorySelected: (category) {
                      setState(() {
                        _selectedCategory =
                            (_selectedCategory == category) ? null : category;
                      });
                    },
                    selectedItem: _selectedCategory,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedOpacity(
              opacity: _showCollectionsCarousel ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showCollectionsCarousel ? 40 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CollectionsCarousel(
                    collections: _tabController.index == 2
                        ? _adShootCollections.map((c) => c['name'] as String).toList()
                        : _getCollectionList().map((c) => c['name']!).toList(),
                    onCollectionSelected: (collection) {
                      setState(() {
                        _selectedCollection =
                            (collection == 'All') ? null : collection;
                        if (_tabController.index == 2 &&
                            _selectedCollection != null) {
                          _fetchAdShootSubCollections(_selectedCollection!);
                        } else {
                          _adShootSubCollections = [];
                          _selectedSubCollection = null;
                        }
                      });
                    },
                    selectedCollection: _selectedCollection,
                  ),
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: _softGold,
                labelColor: _softGold,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Product Shoot'),
                  Tab(text: 'Photo Shoot'),
                  Tab(text: 'Ad Shoot'),
                ],
              ),
            ),
            pinned: true,
          ),
          SliverFillRemaining(
            child: Container(
              color: _matteBlack,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_tabController.index == 2) ...[
                    AnimatedOpacity(
                      opacity: _adShootSubCollections.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: _adShootSubCollections.isNotEmpty ? 30 : 0,
                        child: _buildSubCollectionFilter(),
                      ),
                    ),
                    if (_adShootSubCollections.isNotEmpty) const SizedBox(height: 12),
                  ] else if (_showGenderSwitch) ...[
                    _genderSwitch(),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildProductShootGrid(),
                        _buildTrendingGrid(),
                        _buildAdShootGrid(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _genderSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: _darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      height: 20,
      child: Row(
        children: [
          _genderTab('Men'),
          _genderTab('Women'),
        ],
      ),
    );
  }

  Widget _genderTab(String gender) {
    final bool selected = _selectedGender == gender.toLowerCase();
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender.toLowerCase()),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? _softGold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            gender,
            style: TextStyle(
              color: selected ? _softGold : Colors.white60,
              fontWeight: selected ? FontWeight.bold : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(bool isAdmin) {
    if (_showBackToTopButton) {
      return FloatingActionButton(
        backgroundColor: _softGold,
        onPressed: () {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut);
        },
        child: const Icon(Icons.arrow_upward, color: Colors.black),
      );
    } else if (isAdmin) {
      return FloatingActionButton(
        backgroundColor: _softGold,
        onPressed: () {
          if (_bottomNavIndex == 4) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddReelScreen()),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (context) => const AddTemplateOptionsScreen()),
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      );
    }
    return null;
  }

  Widget _buildProductShootGrid() => _buildFilteredGrid('productshoot');
  Widget _buildTrendingGrid() => _buildFilteredGrid('photoshoot');
  Widget _buildAdShootGrid() => _buildFilteredGrid('adshoot');

  Widget _buildSubCollectionFilter() {
    if (_adShootSubCollections.isEmpty) {
      return const SizedBox.shrink();
    }

    // Add 'All' option to the beginning of the list
    final subCollectionItems = [
      'All',
      ..._adShootSubCollections.map((s) => s['name'] as String)
    ];

    return Container(
      decoration: BoxDecoration(
        color: _darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      height: 30, // Adjusted height
      child: Row(
        children: subCollectionItems.map((subCollectionName) {
          final bool isSelected = _selectedSubCollection == subCollectionName ||
              (_selectedSubCollection == null && subCollectionName == 'All');
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSubCollection =
                      (subCollectionName == 'All') ? null : subCollectionName;
                });
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? _softGold : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  subCollectionName,
                  style: TextStyle(
                    color: isSelected ? _softGold : Colors.white60,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilteredGrid(String type) {
    print('--- Filtering for type: $type ---');
    print('Selected Gender: $_selectedGender');
    print('Selected Category: $_selectedCategory');
    print('Selected Collection: $_selectedCollection');
    print('Total admin templates: ${_allAdminTemplates.length}');

    List<Template> filtered = _allAdminTemplates.where((t) {
      final typeMatch = t.templateType.toLowerCase() == type.toLowerCase();
      final genderMatch =
          t.gender.toLowerCase() == _selectedGender.toLowerCase() ||
              t.gender.toLowerCase() == 'both';
      return typeMatch && genderMatch;
    }).toList();

    print('After type ($type) and gender filter: ${filtered.length} items');

    if (_selectedCategory != null &&
        _selectedCategory!.toLowerCase() != 'all') {
      filtered = filtered
          .where((t) =>
              t.jewelleryType.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
      print(
          'After category filter ($_selectedCategory): ${filtered.length} items');
    }

    if (type == 'adshoot') {
      if (_selectedSubCollection != null) {
        filtered = filtered
            .where((t) => t.collection.any((c) =>
                c.toLowerCase() == _selectedSubCollection!.toLowerCase()))
            .toList();
      }
    } else if (_selectedCollection != null &&
        _selectedCollection!.toLowerCase() != 'all') {
      filtered = filtered
          .where((t) => t.collection.any(
              (c) => c.toLowerCase() == _selectedCollection!.toLowerCase()))
          .toList();
    }

    filtered.sort((a, b) => b.useCount.compareTo(a.useCount));

    print('Final filtered count for type $type: ${filtered.length}');
    if (filtered.isNotEmpty) {
      print('Top 5 templates for $type:');
      for (var i = 0; i < 5 && i < filtered.length; i++) {
        print(
            '  - ${filtered[i].title} (Type: ${filtered[i].templateType}, Gender: ${filtered[i].gender}, Category: ${filtered[i].jewelleryType}, Collections: ${filtered[i].collection})');
      }
    }
    print('--- End of filter for type: $type ---\n');

    final isAdmin =
        FirebaseAuth.instance.currentUser?.email == 'mohithacky890@gmail.com';

    return StaticTemplateGrid(
      templates: filtered,
      onTemplateTap:
          isAdmin ? (template) => _showEditDialog(context, template) : null,
    );
  }

  void _showEditDialog(BuildContext context, Template template) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _darkGrey,
        title: Text('Edit Template', style: TextStyle(color: _softGold)),
        content: const Text('Would you like to edit this template?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddTemplateScreen(
                      template: template, templateType: template.templateType),
                ),
              );
            },
            child: Text('Edit', style: TextStyle(color: _softGold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getCategoryList() => const [
        {'name': 'All', 'image': 'assets/images/logo.png'},
        {'name': 'Earrings', 'image': 'assets/images/earrings.jpg'},
        {'name': 'Bracelet', 'image': 'assets/images/bracelet.jpg'},
        {'name': 'Pendant', 'image': 'assets/images/pendant.jpg'},
        {'name': 'Choker', 'image': 'assets/images/choker.jpg'},
        {'name': 'Ring', 'image': 'assets/images/ring.jpg'},
        {'name': 'Bangles', 'image': 'assets/images/bangles.jpg'},
        {'name': 'Necklace', 'image': 'assets/images/necklace.jpg'},
        {'name': 'Long Necklace', 'image': 'assets/images/long_necklace.jpg'},
        {'name': 'Mangtika', 'image': 'assets/images/mangtika.jpg'},
        {'name': 'Belt Necklace', 'image': 'assets/images/belt_necklace.jpg'},
        {'name': 'Mangalsutra Pendant', 'image': 'assets/images/m_pendant.jpg'},
        {'name': 'Dholna', 'image': 'assets/images/dholna.jpg'},
      ];

  List<Map<String, String>> _getCollectionList() => const [
        {'name': 'All', 'image': 'assets/images/logo.png'},
        {'name': 'Heritage', 'image': 'assets/images/logo.png'},
        {'name': 'Minimal', 'image': 'assets/images/logo.png'},
        {'name': 'Classic', 'image': 'assets/images/logo.png'},
      ];

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildPage(int index, bool isAdmin) {
    switch (index) {
      case 0:
        return _buildHomeScreenBody();
      case 1:
        return isAdmin ? const MyDesignsScreen() : const CollectionsScreen();
      case 2:
        return const UsedTemplatesScreen();
      case 3:
        return const PaymentWebViewScreen();
      case 4:
        return const Center(
          child: Text('Profile Screen - Coming Soon!',
              style: TextStyle(color: Colors.white)),
        );
      case 5:
        return const ReelsScreen();
      default:
        return _buildHomeScreenBody();
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF121212), // _matteBlack
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
