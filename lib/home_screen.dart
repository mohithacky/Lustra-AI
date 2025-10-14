import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/models/template.dart';
import 'package:lustra_ai/services/auth_service.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/screens/add_template_options_screen.dart';
import 'package:lustra_ai/screens/my_designs_screen.dart';
import 'package:lustra_ai/upload_screen.dart';
import 'package:lustra_ai/screens/used_templates_screen.dart';
import 'package:lustra_ai/screens/login_screen.dart';
import 'package:lustra_ai/widgets/static_template_grid.dart';
import 'package:lustra_ai/screens/collections_screen.dart';
import 'package:lustra_ai/screens/shop_details_screen.dart';
import 'package:lustra_ai/widgets/circular_category_carousel.dart';
import 'package:lustra_ai/screens/reels_screen.dart';
import 'package:lustra_ai/screens/add_reel_screen.dart';
import 'package:lustra_ai/screens/add_template_screen.dart';
import 'package:lustra_ai/widgets/collections_carousel.dart';
import 'package:lustra_ai/widgets/ad_shoot_grid.dart';

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
  bool _showGenderSwitch = true;

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
            _showGenderSwitch = _tabController.index != 2;
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
          isAdmin
              ? _navItem(Icons.design_services_outlined, 'My Designs', 1)
              : _navItem(Icons.collections_outlined, 'Collections', 1),
          if (isAdmin) const SizedBox(width: 48),
          _navItem(Icons.history_outlined, 'Used', 2),
          _navItem(Icons.person_outline, 'Profile', 3),
          _navItem(Icons.play_circle_outline, 'Reels', 4),
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

  Widget _buildHomeScreenBody() {
    final user = FirebaseAuth.instance.currentUser;

    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) {
        return [
          SliverAppBar(
            backgroundColor: _matteBlack,
            elevation: 0,
            floating: true,
            centerTitle: true,
            title: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFF8EAC2), // light champagne
                  Color(0xFFE2C06D), // warm soft gold
                  Color(0xFFF4E7C0), // pale cream finish
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                "LUSTRA AI",
                style: TextStyle(
                  color: Colors.white, // base color (acts as mask)
                  fontSize: 28,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            leading: const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundImage: AssetImage("assets/images/logo.png"),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: () async {
                  await _auth.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(250),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: CircularCategoryCarousel(
                      categories: _getCategoryList(),
                      onCategorySelected: (category) {
                        setState(() {
                          if (category == 'All') {
                            _selectedCategory = null;
                          } else if (_selectedCategory == category) {
                            _selectedCategory = null;
                          } else {
                            _selectedCategory = category;
                          }
                        });
                      },
                      selectedItem: _selectedCategory,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: CollectionsCarousel(),
                  ),
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
                ],
              ),
            ),
          ),
        ];
      },
      body: Container(
        color: _matteBlack,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (_showGenderSwitch) _genderSwitch(),
            if (_showGenderSwitch) const SizedBox(height: 12),
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
    );
  }

  Widget _genderSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: _darkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      height: 42,
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
  Widget _buildAdShootGrid() {
    List<Template> filtered = _allAdminTemplates
        .where((t) => t.templateType.toLowerCase() == 'adshoot')
        .toList();

    if (_selectedCategory != null) {
      filtered = filtered
          .where((t) =>
              t.jewelleryType.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }
    if (_selectedCollection != null) {
      filtered = filtered
          .where((t) => t.collection.contains(_selectedCollection!))
          .toList();
    }

    filtered.sort((a, b) => b.useCount.compareTo(a.useCount));
    final isAdmin =
        FirebaseAuth.instance.currentUser?.email == 'mohithacky890@gmail.com';

    return AdShootGrid(
      templates: filtered,
      onTemplateTap:
          isAdmin ? (template) => _showEditDialog(context, template) : null,
    );
  }

  Widget _buildFilteredGrid(String type) {
    List<Template> filtered = _allAdminTemplates
        .where((t) =>
            t.templateType.toLowerCase() == type &&
            (t.gender.toLowerCase() == _selectedGender ||
                t.gender.toLowerCase() == 'both'))
        .toList();

    if (_selectedCategory != null) {
      filtered = filtered
          .where((t) =>
              t.jewelleryType.toLowerCase() == _selectedCategory!.toLowerCase())
          .toList();
    }
    if (_selectedCollection != null) {
      filtered = filtered
          .where((t) => t.collection.contains(_selectedCollection!))
          .toList();
    }

    filtered.sort((a, b) => b.useCount.compareTo(a.useCount));
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
        return const Center(
            child: Text('Profile Screen - Coming Soon!',
                style: TextStyle(color: Colors.white)));
      case 4:
        return const ReelsScreen();
      default:
        return _buildHomeScreenBody();
    }
  }
}
