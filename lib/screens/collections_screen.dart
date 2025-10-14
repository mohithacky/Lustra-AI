import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lustra_ai/screens/add_collection_screen.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/screens/add_category_screen.dart';
import 'package:lustra_ai/screens/products_page.dart';

// --- Theme and Styling Constants ---

const Color kOffWhite = Color(0xFFF8F7F4);
const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);
bool isMobile = false;

final TextTheme kTextTheme = TextTheme(
  // Elegant Serif for large, important titles
  displayLarge: GoogleFonts.lora(
      fontSize: 48, fontWeight: FontWeight.bold, color: kBlack),
  // Serif for smaller headlines
  headlineSmall: GoogleFonts.lora(
      fontSize: 24, fontWeight: FontWeight.w700, color: kBlack),
  // Clean Sans-Serif for body text and paragraphs
  bodyLarge: GoogleFonts.lato(fontSize: 16, color: kBlack, height: 1.5),
  // Lighter Sans-Serif for subtitles and less important text
  bodyMedium: GoogleFonts.lato(fontSize: 14, color: kBlack.withOpacity(0.7)),
  // Bolder Sans-Serif for buttons and labels
  labelLarge: GoogleFonts.lato(
      fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
);

// --- Main Screen Widget ---

class CollectionsScreen extends StatefulWidget {
  final String? shopName;
  final String? logoUrl;
  final String? userId;

  const CollectionsScreen({Key? key, this.shopName, this.logoUrl, this.userId})
      : super(key: key);

  @override
  _CollectionsScreenState createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  String? _shopName;
  String? _logoUrl;
  String? _websiteUrl;
  bool _isDeploying = false;
  bool _isLoading = true;
  final GlobalKey<_HeroCarouselState> _carouselKey =
      GlobalKey<_HeroCarouselState>();

  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<Map<String, String>>> _categoriesFuture;

  void _navigateAndAddCategory() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddCategoryScreen()),
    );

    if (result == true) {
      setState(() {
        _categoriesFuture =
            _firestoreService.getCategories(userId: widget.userId);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _firestoreService.getCategories(userId: widget.userId);
    if (kIsWeb && widget.shopName != null) {
      // Web platform: Use passed-in data
      _shopName = widget.shopName;
      _logoUrl = widget.logoUrl;
      _websiteUrl =
          'https://lustra-ai.web.app'; // Set a default website URL for web mode
      _isLoading = false;
    } else {
      // Mobile platform: Fetch from Firestore
      _fetchShopDetails();
    }
  }

  Future<void> _fetchShopDetails() async {
    // Mobile platform: Fetch from Firestore
    final firestoreService = FirestoreService();
    final details = await firestoreService.getUserDetails();
    if (details != null) {
      setState(() {
        _shopName = details['shopName'];
        _logoUrl = details['logoUrl'];
        _websiteUrl = details['websiteUrl']; // Fetch the website URL
        _isLoading = false;
      });
    } else {
      // Ensure loading is turned off even if details are null
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deployWebsite() async {
    setState(() {
      _isDeploying = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Deploying website..."),
            ],
          ),
        );
      },
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in.');
      }

      final idToken = await user.getIdToken(true);
      final url = Uri.parse(
          'https://central-miserably-sunbird.ngrok-free.app/deploy'); // Fixed to match the correct ngrok tunnel

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final websiteUrl = responseBody['websiteUrl'];

        // Update state to show buttons
        setState(() {
          _websiteUrl = websiteUrl;
        });

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Deployment Successful'),
              content: Text('Your website is live at: $websiteUrl'),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Failed to deploy website: ${response.body}');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog on error
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Deployment Failed'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } finally {
      setState(() {
        _isDeploying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    isMobile = MediaQuery.of(context).size.width <= 600;
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      floatingActionButton: kIsWeb
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_websiteUrl != null && _websiteUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FloatingActionButton.extended(
                      onPressed: _isDeploying ? null : _deployWebsite,
                      label: _isDeploying
                          ? const Text('Redeploying...')
                          : const Text('Redeploy Website'),
                      icon: const Icon(Icons.refresh),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      heroTag: 'redeploy',
                    ),
                  ),
                FloatingActionButton.extended(
                  onPressed: _isDeploying ? null : _deployWebsite,
                  label: _isDeploying
                      ? const Text('Deploying...')
                      : const Text('Host Website'),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  backgroundColor: kGold,
                  foregroundColor: Colors.white,
                  heroTag: 'deploy',
                ),
              ],
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: _buildSlivers(context),
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context) {
    final slivers = <Widget>[];

    // Add a modern App Bar inspired by GIVA design
    slivers.add(SliverAppBar(
      backgroundColor: Colors.white,
      floating: true,
      pinned: true,
      elevation: 0,
      leadingWidth: 60,
      // Left hamburger menu
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: IconButton(
          icon: const Icon(Icons.menu, color: kBlack),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      // Center logo
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_shopName ?? 'MYBRAND',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 26, color: kBlack, fontWeight: FontWeight.bold)),
        ],
      ),
      centerTitle: true,
      // Right icons
      actions: [
        IconButton(
          icon: const Icon(Icons.favorite_border, color: kBlack),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined, color: kBlack),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.person_outline, color: kBlack),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
      // Search bar below the app bar
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search jewellery',
              hintStyle: GoogleFonts.lato(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
      ),
    ));

    // Conditionally add the buttons if the website is hosted (but not on web platform)
    if (_websiteUrl != null && _websiteUrl!.isNotEmpty && !kIsWeb) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddCollectionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Collection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _carouselKey.currentState?.refreshCollections();
                  },
                  icon: const Icon(Icons.update),
                  label: const Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }

    // Add the rest of the content
    slivers.addAll([
      // Add space above the banner
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      // HeroCarousel
      SliverToBoxAdapter(
          child: HeroCarousel(key: _carouselKey, userId: widget.userId)),
      // Reduce space between banner and categories
      const SliverToBoxAdapter(child: SizedBox(height: 10)),
      // CategoryCarousel
      const SliverToBoxAdapter(child: CategoryCarousel()),
      // Add the new 'Shop by Recipient' section
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
      const SliverToBoxAdapter(child: ShopByRecipientSection()),
      const SliverToBoxAdapter(child: SizedBox(height: 60)),
      SliverToBoxAdapter(
        child: FutureBuilder<List<Map<String, String>>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error loading categories: ${snapshot.error}'));
            }

            final categories = snapshot.data ?? [];

            return CategoryShowcase(
              categories: categories,
              onAddCategory: _navigateAndAddCategory,
            );
          },
        ),
      ),
      // Height spacer between categories and product showcase
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
      const SliverToBoxAdapter(child: ProductShowcase()),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
      // const SliverToBoxAdapter(child: ShopByMood()),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
      const SliverToBoxAdapter(child: FeaturedStories()),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
      // const SliverToBoxAdapter(child: TestimonialsAndSocialProof()),
      const SliverToBoxAdapter(child: SizedBox(height: 80)),
      const SliverToBoxAdapter(child: Footer()),
    ]);

    return slivers;
  }

  // Helper methods removed as they're no longer used
}

// --- Reusable Modular Widgets (Placeholders) ---

class HeroCarousel extends StatefulWidget {
  final String? userId;
  const HeroCarousel({Key? key, this.userId}) : super(key: key);

  @override
  _HeroCarouselState createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel>
    with SingleTickerProviderStateMixin {
  int _current = 0;
  final PageController _pageController = PageController();
  late Future<List<Map<String, dynamic>>> _collectionsFuture;
  Timer? _autoPlayTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;

  void refreshCollections() {
    setState(() {
      _collectionsFuture =
          FirestoreService().getCollections(userId: widget.userId);
    });
  }

  @override
  void initState() {
    super.initState();
    _collectionsFuture =
        FirestoreService().getCollections(userId: widget.userId);

    // Set up animation controller for sliding effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Autoplay will start when data is loaded from Firestore.
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startAutoPlay(int itemCount) {
    if (itemCount == 0) return;
    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        if (_current < (itemCount - 1)) {
          _pageController.animateToPage(
            _current + 1,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        } else {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _collectionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 16 / 6,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return AspectRatio(
            aspectRatio: 16 / 6,
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const AspectRatio(
            aspectRatio: 16 / 6,
            child: Center(child: Text('No collections found.')),
          );
        }

        final collections = snapshot.data!;
        // Restart autoplay when data is loaded
        _autoPlayTimer?.cancel();
        _startAutoPlay(collections.length);

        return Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 6, // Updated aspect ratio
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _current = index;
                    _animationController.reset();
                    _animationController.forward();
                  });
                },
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  return _buildBannerSlide(collections[index], isMobile);
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: collections.asMap().entries.map((entry) {
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      entry.key,
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _current == entry.key
                          ? kBlack
                          : kBlack.withOpacity(0.3),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBannerSlide(Map<String, dynamic> collection, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
              collection['bannerUrl']), // Use 'bannerUrl' from Firestore
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.6),
              Colors.black.withOpacity(0.3),
              Colors.transparent,
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0.0, 0.5, 0.9],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: MediaQuery.of(context).size.width *
                0.05, // Use width-proportional padding to prevent overflow
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _animation,
                child: Text(
                  collection['name'], // Use 'name' from Firestore
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isMobile ? 28 : 42,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _animation,
                child: Text(
                  'Discover the new collection',
                  style: GoogleFonts.lato(
                    fontSize: isMobile ? 16 : 20,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Removed unused method
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MYBRAND',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      color: kBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Fine Jewellery', style: TextStyle(fontSize: 14)),
                  const Spacer(),
                  const Divider(),
                ],
              ),
            ),
            _buildDrawerItem('Home', Icons.home_outlined),
            _buildDrawerItem('Categories', Icons.category_outlined),
            _buildDrawerItem('New Arrivals', Icons.new_releases_outlined),
            _buildDrawerItem('Bestsellers', Icons.star_outline),
            _buildDrawerItem('Gifts', Icons.card_giftcard),
            _buildDrawerItem('My Orders', Icons.shopping_bag_outlined),
            _buildDrawerItem('Wishlist', Icons.favorite_border),
            _buildDrawerItem('My Account', Icons.person_outline),
            const Divider(),
            _buildDrawerItem('Contact Us', Icons.support_agent),
            _buildDrawerItem('FAQs', Icons.help_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: kBlack),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: kBlack),
      ),
      onTap: () {},
    );
  }
}

class CategoryShowcase extends StatelessWidget {
  final List<Map<String, String>> categories;
  final VoidCallback onAddCategory;

  const CategoryShowcase(
      {Key? key, required this.categories, required this.onAddCategory})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final double aspectRatio = isMobile
        ? MediaQuery.of(context).size.width / 300
        : MediaQuery.of(context).size.width / 1700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        children: [
          Text(
            'Find Your Perfect Match',
            textAlign: TextAlign.center,
            style: kTextTheme.headlineSmall?.copyWith(
              fontSize: isMobile ? 28 : 36,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Shop By Categories',
            textAlign: TextAlign.center,
            style: kTextTheme.bodyMedium?.copyWith(
              fontSize: isMobile ? 16 : 18,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 24, color: Colors.purple),
            onPressed: onAddCategory,
          ),
          const SizedBox(height: 40),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: aspectRatio,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return CategoryCard(category: categories[index]);
            },
          ),
        ],
      ),
    );
  }
}

class CategoryCard extends StatefulWidget {
  final Map<String, String> category;

  const CategoryCard({Key? key, required this.category}) : super(key: key);

  @override
  _CategoryCardState createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Get the parent CollectionsScreen state to access shop details
        final _CollectionsScreenState? collectionsState =
            context.findAncestorStateOfType<_CollectionsScreenState>();
        final shopName = collectionsState?._shopName ?? 'Lustra';
        final logoUrl = collectionsState?._logoUrl;

        // Navigate to products page when category is tapped
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductsPage(
              categoryName: widget.category['name']!,
              products: _getDummyProductsForCategory(widget.category['name']!),
              shopName: shopName,
              logoUrl: logoUrl,
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16), // 2xl
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transform: _isHovered
                    ? (Matrix4.identity()..scale(1.05))
                    : Matrix4.identity(),
                transformAlignment: Alignment.center,
                child: Image.network(
                  widget.category['image']!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kBlack.withOpacity(0.7), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                child: Column(
                  children: [
                    Text(
                      widget.category['name']!,
                      style: kTextTheme.headlineSmall?.copyWith(
                        color: kOffWhite,
                        fontSize: isMobile
                            ? MediaQuery.of(context).size.width * 0.05
                            : MediaQuery.of(context).size.width * 0.015,
                        fontWeight:
                            _isHovered ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 2,
                      width: _isHovered ? 40 : 0,
                      color: kGold,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to generate dummy products for each category
  List<Map<String, dynamic>> _getDummyProductsForCategory(String category) {
    // Base products list with common properties
    final List<Map<String, dynamic>> products = [
      {
        'name': 'Diamond Pendant Necklace',
        'price': '24,999',
        'imagePath':
            'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?ixlib=rb-4.0.3',
        'discount': '7% off on making charges',
        'isBestseller': true,
      },
      {
        'name': 'Gold Hoop Earrings',
        'price': '12,500',
        'originalPrice': '15,000',
        'imagePath':
            'https://images.unsplash.com/photo-1630019852942-f89202989a59?ixlib=rb-4.0.3',
        'discount': '5% off on making charges',
      },
      {
        'name': 'Pearl Stud Earrings',
        'price': '8,750',
        'imagePath':
            'https://images.unsplash.com/photo-1611107683227-e9060eccd846?ixlib=rb-4.0.3',
      },
      {
        'name': 'Ruby Cocktail Ring',
        'price': '35,000',
        'imagePath':
            'https://images.unsplash.com/photo-1605100804763-247f67b3557e?ixlib=rb-4.0.3',
        'discount': '10% off on gemstone price',
        'isBestseller': true,
      },
      {
        'name': 'Gold Chain Bracelet',
        'price': '18,999',
        'originalPrice': '21,500',
        'imagePath':
            'https://images.unsplash.com/photo-1611652022419-a9419f74343d?ixlib=rb-4.0.3',
        'discount': '8% off on making charges',
      },
      {
        'name': 'Emerald Statement Necklace',
        'price': '45,000',
        'imagePath':
            'https://images.unsplash.com/photo-1599459183085-9b9f310f471f?ixlib=rb-4.0.3',
        'isBestseller': true,
      },
      {
        'name': 'Diamond Tennis Bracelet',
        'price': '65,000',
        'originalPrice': '72,000',
        'imagePath':
            'https://images.unsplash.com/photo-1602173574767-37ac01994b2a?ixlib=rb-4.0.3',
        'discount': '15% off on diamond price',
      },
      {
        'name': 'Rose Gold Bangles Set',
        'price': '28,500',
        'imagePath':
            'https://images.unsplash.com/photo-1601121141461-9d6647bca1ed?ixlib=rb-4.0.3',
        'discount': '5% off on making charges',
      },
      {
        'name': 'Sapphire Eternity Ring',
        'price': '32,999',
        'imagePath':
            'https://images.unsplash.com/photo-1608042314453-ae338d80c427?ixlib=rb-4.0.3',
        'isBestseller': true,
      },
    ];

    return products;
  }
}

class CollectionBanner extends StatefulWidget {
  final String? shopName;
  final String? logoUrl;

  const CollectionBanner({Key? key, this.shopName, this.logoUrl})
      : super(key: key);

  @override
  _CollectionBannerState createState() => _CollectionBannerState();
}

class _CollectionBannerState extends State<CollectionBanner> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 40.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), // 2xl
          boxShadow: [
            BoxShadow(
              color: kBlack.withOpacity(_isHovered ? 0.15 : 0.05),
              blurRadius: _isHovered ? 30 : 15,
              offset: Offset(0, _isHovered ? 15 : 5),
            ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0, -10, 0))
            : Matrix4.identity(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 350,
                decoration: BoxDecoration(
                  color: kBlack.withOpacity(0.1),
                ),
              ),
              Container(
                height: 350,
                decoration: BoxDecoration(color: kBlack.withOpacity(0.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductShowcase extends StatelessWidget {
  const ProductShowcase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> products = [
      {
        'name': 'Gold Weave Ring',
        'price': '\$699',
        'image':
            'https://via.placeholder.com/500x500/F8F7F4/000000?text=Product+1'
      },
      {
        'name': 'Diamond Studs',
        'price': '\$1,299',
        'image':
            'https://via.placeholder.com/500x500/F8F7F4/000000?text=Product+2'
      },
      {
        'name': 'Pearl Necklace',
        'price': '\$899',
        'image':
            'https://via.placeholder.com/500x500/F8F7F4/000000?text=Product+3'
      },
      {
        'name': 'Sapphire Bracelet',
        'price': '\$1,499',
        'image':
            'https://via.placeholder.com/500x500/F8F7F4/000000?text=Product+4'
      },
      {
        'name': 'Ruby Pendant',
        'price': '\$999',
        'image':
            'https://via.placeholder.com/500x500/F8F7F4/000000?text=Product+5'
      },
    ];

    return Column(
      children: [
        _buildSectionHeader(context),
        const SizedBox(height: 40),
        SizedBox(
          height: 420, // Adjust height to fit card content
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return ProductCard(product: products[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoSizeText('New Arrivals',
                  style: kTextTheme.displayLarge?.copyWith(
                      fontSize: MediaQuery.of(context).size.width * 0.07),
                  maxLines: 1,
                  minFontSize: 20),
              const SizedBox(height: 8),
              Text(
                'Curated just for you',
                style: kTextTheme.bodyLarge?.copyWith(
                    color: kBlack.withOpacity(0.6),
                    fontSize: MediaQuery.of(context).size.width * 0.04),
              ),
            ],
          )),
          Text('View All →',
              style: kTextTheme.bodyLarge
                  ?.copyWith(color: kGold, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final Map<String, String> product;

  const ProductCard({Key? key, required this.product}) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: MediaQuery.of(context).size.width * 0.7,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // 2xl
          boxShadow: [
            BoxShadow(
              color: kBlack.withOpacity(_isHovered ? 0.1 : 0.05),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0, -8, 0))
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      decoration: BoxDecoration(
                        color: kBlack.withOpacity(0.05),
                      ),
                    ),
                  ),
                  if (_isHovered)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kOffWhite.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_border,
                            color: kBlack, size: 24),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.product['name']!,
                      style: kTextTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(widget.product['price']!,
                      style: kTextTheme.bodyLarge?.copyWith(
                          color: kGold, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Add to Cart',
                          style: kTextTheme.labelLarge
                              ?.copyWith(color: Colors.white)),
                    ),
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

class FeatureCard extends StatefulWidget {
  final Map<String, dynamic> feature;
  final int index;

  const FeatureCard({Key? key, required this.feature, required this.index})
      : super(key: key);

  @override
  _FeatureCardState createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Staggered animation
    Future.delayed(Duration(milliseconds: 150 * widget.index), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16), // xl
              border: Border.all(
                color: _isHovered ? kGold : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: kBlack.withOpacity(_isHovered ? 0.08 : 0.04),
                  blurRadius: _isHovered ? 25 : 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(widget.feature['icon'],
                      color: kGold, size: isMobile ? 32 : 40),
                  const SizedBox(height: 16),
                  AutoSizeText(
                    widget.feature['title'],
                    textAlign: TextAlign.center,
                    style: kTextTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    minFontSize: 14,
                  ),
                  if (!isMobile) ...[
                    const SizedBox(height: 8),
                    AutoSizeText(
                      widget.feature['subtitle'],
                      textAlign: TextAlign.center,
                      style: kTextTheme.bodyMedium
                          ?.copyWith(color: kBlack.withOpacity(0.6)),
                      maxLines: 3,
                      minFontSize: 12,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// class ShopByMood extends StatelessWidget {
//   const ShopByMood({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final List<Map<String, String>> moods = [
//       {'name': 'Wedding', 'image': ''},
//       {'name': 'Gifting', 'image': ''},
//       {'name': 'Daily Wear', 'image': ''},
//       {'name': 'Party Wear', 'image': ''},
//     ];

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 40.0),
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           int crossAxisCount;
//           if (constraints.maxWidth > 1200) {
//             crossAxisCount = 4;
//           } else if (constraints.maxWidth > 800) {
//             crossAxisCount = 2;
//           } else {
//             crossAxisCount = 1;
//           }

//           return GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: crossAxisCount,
//               crossAxisSpacing: 20,
//               mainAxisSpacing: 20,
//               childAspectRatio: 0.8,
//             ),
//             itemCount: moods.length,
//             itemBuilder: (context, index) {
//               return MoodCard(mood: moods[index]);
//             },
//           );
//         },
//       ),
//     );
//   }
// }

class MoodCard extends StatefulWidget {
  final Map<String, String> mood;

  const MoodCard({Key? key, required this.mood}) : super(key: key);

  @override
  _MoodCardState createState() => _MoodCardState();
}

class _MoodCardState extends State<MoodCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // 2xl
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: _isHovered
                  ? (Matrix4.identity()..scale(1.05))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              child: Container(color: kBlack.withOpacity(0.1)),
            ),
            Container(
                decoration: BoxDecoration(color: kBlack.withOpacity(0.3))),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.mood['name']!,
                  style: kTextTheme.displayLarge?.copyWith(
                    color: kOffWhite,
                    fontSize: 32,
                    shadows: [
                      if (_isHovered)
                        const Shadow(color: kGold, blurRadius: 15),
                    ],
                  ),
                ),
              ],
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              bottom: _isHovered ? 20 : -60,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGold,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Explore Now →',
                    style:
                        kTextTheme.labelLarge?.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturedStories extends StatelessWidget {
  const FeaturedStories({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        StoryBanner(
          title: 'The Minimalist Edit',
          description: 'Timeless designs for the modern woman. Less is more.',
          layout: 'image_left',
        ),
        SizedBox(height: 40),
        StoryBanner(
          title: 'Heritage Gold',
          description:
              'Explore our collection of classic, handcrafted gold jewelry.',
          layout: 'image_right',
        ),
      ],
    );
  }
}

class StoryBanner extends StatefulWidget {
  final String title;
  final String description;
  final String layout;

  const StoryBanner({
    Key? key,
    required this.title,
    required this.description,
    required this.layout,
  }) : super(key: key);

  @override
  _StoryBannerState createState() => _StoryBannerState();
}

class _StoryBannerState extends State<StoryBanner>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // The slide direction depends on the layout
    final slideBegin = widget.layout == 'image_right'
        ? const Offset(-0.2, 0)
        : const Offset(0.2, 0);

    _slideAnimation =
        Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // For simplicity, we'll trigger the animation on build.
    // A more robust solution would use a visibility detector.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    bool isFullWidth = widget.layout == 'full_width';

    if (isFullWidth) {
      return _buildFullWidthBanner();
    }

    List<Widget> children = [
      _buildImageAsset(),
      _buildTextContent(),
    ];

    if (widget.layout == 'image_right') {
      children = children.reversed.toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: isMobile
          ? Column(children: children)
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Flexible(child: children[0]),
              Flexible(child: children[1]),
            ]),
    );
  }

  Widget _buildFullWidthBanner() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              transform: _isHovered
                  ? (Matrix4.identity()..scale(1.05))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              height: 400,
              decoration: BoxDecoration(color: kBlack.withOpacity(0.1)),
            ),
            Container(
                height: 400,
                decoration: BoxDecoration(color: kBlack.withOpacity(0.4))),
            _buildTextContent(isOverlay: true),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAsset() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          transform: _isHovered
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          transformAlignment: Alignment.center,
          height: 450,
          decoration: BoxDecoration(color: kBlack.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildTextContent({bool isOverlay = false}) {
    final textColor = isOverlay ? kOffWhite : kBlack;
    final subtitleColor =
        isOverlay ? kOffWhite.withOpacity(0.8) : kBlack.withOpacity(0.7);

    final content = SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.all(
            MediaQuery.of(context).size.width < 800 ? 24.0 : 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment:
              isOverlay ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            AutoSizeText(
              widget.title,
              textAlign: isOverlay ? TextAlign.center : TextAlign.left,
              style: kTextTheme.displayLarge
                  ?.copyWith(fontSize: 32, color: textColor),
              maxLines: 2,
              minFontSize: 20,
            ),
            const SizedBox(height: 16),
            Text(
              widget.description,
              textAlign: isOverlay ? TextAlign.center : TextAlign.left,
              style: kTextTheme.bodyLarge?.copyWith(color: subtitleColor),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: kGold,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Explore Collection',
                  style: kTextTheme.labelLarge?.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (isOverlay) {
      return content;
    }

    return content;
  }
}

class TestimonialsCarousel extends StatefulWidget {
  const TestimonialsCarousel({Key? key}) : super(key: key);

  @override
  _TestimonialsCarouselState createState() => _TestimonialsCarouselState();
}

class _TestimonialsCarouselState extends State<TestimonialsCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.8);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final double viewportFraction = isMobile ? 0.8 : 1 / 3.2;

    final List<Map<String, String>> testimonials = [
      {
        'quote': 'Absolutely in love with the quality and design!',
        'name': 'Jessica L.',
        'avatar': ''
      },
      {
        'quote': 'The perfect gift. My wife was thrilled!',
        'name': 'Michael B.',
        'avatar': ''
      },
      {
        'quote': 'Stunning pieces and exceptional customer service.',
        'name': 'Priya S.',
        'avatar': ''
      },
      {
        'quote': 'My new favorite earrings. I wear them everywhere!',
        'name': 'Emily R.',
        'avatar': ''
      },
    ];

    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: PageController(viewportFraction: viewportFraction),
        itemCount: testimonials.length,
        itemBuilder: (context, index) {
          return TestimonialCard(testimonial: testimonials[index]);
        },
      ),
    );
  }
}

class TestimonialCard extends StatefulWidget {
  final Map<String, String> testimonial;

  const TestimonialCard({Key? key, required this.testimonial})
      : super(key: key);

  @override
  _TestimonialCardState createState() => _TestimonialCardState();
}

class _TestimonialCardState extends State<TestimonialCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // xl
          boxShadow: [
            BoxShadow(
              color: kBlack.withOpacity(_isHovered ? 0.1 : 0.05),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0, -10, 0))
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: List.generate(5,
                    (index) => const Icon(Icons.star, color: kGold, size: 20))),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  '“${widget.testimonial['quote']!}”',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: kBlack.withOpacity(0.8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                    radius: 24, backgroundColor: kBlack.withOpacity(0.1)),
                const SizedBox(width: 12),
                Text(widget.testimonial['name']!,
                    style: kTextTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InstagramFeed extends StatelessWidget {
  const InstagramFeed({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount;
          if (constraints.maxWidth > 1200) {
            crossAxisCount = 6;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 3;
          } else {
            crossAxisCount = 2;
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              return const InstagramPostCard();
            },
          );
        },
      ),
    );
  }
}

class InstagramPostCard extends StatefulWidget {
  const InstagramPostCard({Key? key}) : super(key: key);

  @override
  _InstagramPostCardState createState() => _InstagramPostCardState();
}

class _InstagramPostCardState extends State<InstagramPostCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: _isHovered
                  ? (Matrix4.identity()..scale(1.1))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              child: Container(color: kBlack.withOpacity(0.1)),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isHovered ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(color: kBlack.withOpacity(0.4)),
                child: Center(
                  child: Text(
                    'View Post →',
                    style: kTextTheme.labelLarge?.copyWith(
                        color: kOffWhite,
                        shadows: [const Shadow(color: kGold, blurRadius: 10)]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isMobile ? _buildMobileFooter() : _buildDesktopFooter(),
          const SizedBox(height: 60),
          Divider(color: kBlack.withOpacity(0.1)),
          const SizedBox(height: 20),
          _buildMiniBar(),
        ],
      ),
    );
  }

  Widget _buildDesktopFooter() {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            flex: 2,
            child: _FooterColumn(
                title: 'About', links: ['Our Story', 'Careers', 'Press'])),
        Expanded(
            flex: 2,
            child: _FooterColumn(
                title: 'Shop',
                links: ['Earrings', 'Necklaces', 'Rings', 'Collections'])),
        Expanded(
            flex: 2,
            child: _FooterColumn(title: 'Customer Care', links: [
              'FAQs',
              'Contact Us',
              'Shipping & Returns',
              'Warranty'
            ])),
        Expanded(flex: 3, child: _ConnectColumn()),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterColumn(title: 'About', links: ['Our Story', 'Careers', 'Press']),
        SizedBox(height: 40),
        _FooterColumn(
            title: 'Shop',
            links: ['Earrings', 'Necklaces', 'Rings', 'Collections']),
        SizedBox(height: 40),
        _FooterColumn(
            title: 'Customer Care',
            links: ['FAQs', 'Contact Us', 'Shipping & Returns', 'Warranty']),
        SizedBox(height: 40),
        _ConnectColumn(),
      ],
    );
  }

  Widget _buildMiniBar() {
    return LayoutBuilder(builder: (context, constraints) {
      final bool isMobile = constraints.maxWidth < 600;
      return isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('© 2024 Lustra. All Rights Reserved.',
                    style: kTextTheme.bodyMedium),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FooterLink(text: 'Privacy Policy'),
                    SizedBox(width: 20),
                    _FooterLink(text: 'Terms of Service'),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('© 2024 Lustra. All Rights Reserved.',
                    style: kTextTheme.bodyMedium),
                const Row(
                  children: [
                    _FooterLink(text: 'Privacy Policy'),
                    SizedBox(width: 20),
                    _FooterLink(text: 'Terms of Service'),
                  ],
                ),
              ],
            );
    });
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _FooterColumn({Key? key, required this.title, required this.links})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(title,
            style: kTextTheme.headlineSmall?.copyWith(fontSize: 20),
            maxLines: 1,
            minFontSize: 14),
        const SizedBox(height: 24),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _FooterLink(text: link),
            )),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String text;
  const _FooterLink({Key? key, required this.text}) : super(key: key);

  @override
  __FooterLinkState createState() => __FooterLinkState();
}

class __FooterLinkState extends State<_FooterLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          widget.text,
          style: kTextTheme.bodyLarge
              ?.copyWith(color: _isHovered ? kGold : kBlack.withOpacity(0.8)),
        ),
      ),
    );
  }
}

class _ConnectColumn extends StatelessWidget {
  const _ConnectColumn({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect & Subscribe',
            style: kTextTheme.headlineSmall?.copyWith(fontSize: 20)),
        const SizedBox(height: 24),
        const Text('Get exclusive offers and first access to new collections.'),
        const SizedBox(height: 16),
        const _NewsletterSignup(),
        const SizedBox(height: 24),
        const Row(
          children: [
            _SocialIcon(icon: Icons.facebook),
            SizedBox(width: 16),
            _SocialIcon(icon: Icons.camera_alt_outlined),
            SizedBox(width: 16),
            _SocialIcon(icon: Icons.video_call_outlined),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Download Our App'),
        const SizedBox(height: 16),
        Row(
          children: [
            _appStoreButton('App Store'),
            const SizedBox(width: 12),
            _appStoreButton('Google Play'),
          ],
        ),
      ],
    );
  }

  Widget _appStoreButton(String store) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: kBlack,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Icon(store == 'App Store' ? Icons.apple : Icons.shop,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store,
                      style: kTextTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsletterSignup extends StatefulWidget {
  const _NewsletterSignup({Key? key}) : super(key: key);

  @override
  __NewsletterSignupState createState() => __NewsletterSignupState();
}

class __NewsletterSignupState extends State<_NewsletterSignup> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_isFocused)
              BoxShadow(color: kGold.withOpacity(0.5), blurRadius: 8),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Enter your email',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(4.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                style: IconButton.styleFrom(
                    backgroundColor: kGold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialIcon extends StatefulWidget {
  final IconData icon;
  const _SocialIcon({Key? key, required this.icon}) : super(key: key);

  @override
  __SocialIconState createState() => __SocialIconState();
}

class __SocialIconState extends State<_SocialIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(widget.icon, color: _isHovered ? kGold : kBlack, size: 28),
      ),
    );
  }
}

class CategoryCarousel extends StatelessWidget {
  const CategoryCarousel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // GIVA-style categories with pastel backgrounds
    final List<Map<String, String>> categories = [
      {
        'categoryName': 'Pendants',
        'imageURL':
            'https://images.unsplash.com/photo-1611652022419-a9419f74343d?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Rings',
        'imageURL':
            'https://images.unsplash.com/photo-1605100804763-247f67b3557e?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Earrings',
        'imageURL':
            'https://images.unsplash.com/photo-1630019852942-f89202989a59?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Bracelets',
        'imageURL':
            'https://images.unsplash.com/photo-1611652022419-a9419f74343d?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Bangles',
        'imageURL':
            'https://images.unsplash.com/photo-1601121141461-9d6647bca1ed?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Mangalsutras',
        'imageURL':
            'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Nosepin',
        'imageURL':
            'https://images.unsplash.com/photo-1611107683227-e9060eccd846?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Toe Rings',
        'imageURL':
            'https://images.unsplash.com/photo-1602173574767-37ac01994b2a?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Silver Chains',
        'imageURL':
            'https://images.unsplash.com/photo-1611652022419-a9419f74343d?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Gold Jewellery',
        'imageURL':
            'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
      {
        'categoryName': 'Personalised',
        'imageURL':
            'https://images.unsplash.com/photo-1605100804763-247f67b3557e?ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&ixlib=rb-1.2.1&auto=format&fit=crop&w=150&q=80'
      },
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title for the category section
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Text(
              'Shop By Category',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Horizontal scrollable category grid
          SizedBox(
            height: isMobile ? 130 : 160, // Adjusted height for desktop
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return CategoryItem(
                  categoryName: categories[index]['categoryName']!,
                  imageURL: categories[index]['imageURL']!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ShopByRecipientSection extends StatelessWidget {
  const ShopByRecipientSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      color: Colors.white,
      child: Column(
        children: [
          Text(
            'Shop by Recipient',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRecipientCard(
                context,
                'Him',
                'https://images.unsplash.com/photo-1615933454938-06a5293b89a3?auto=format&fit=crop&w=800&q=80',
              ),
              _buildRecipientCard(
                context,
                'Her',
                'https://images.unsplash.com/photo-1611556859744-9f0a28a5a6d7?auto=format&fit=crop&w=800&q=80',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(BuildContext context, String title, String imageUrl) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.yellow.shade100, Colors.pink.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Image.network(imageUrl, fit: BoxFit.cover, height: 200),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              color: Colors.brown.shade700,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Collection',
                    style: GoogleFonts.lato(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryItem extends StatefulWidget {
  final String categoryName;
  final String imageURL;

  const CategoryItem({
    Key? key,
    required this.categoryName,
    required this.imageURL,
  }) : super(key: key);

  @override
  _CategoryItemState createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final _CollectionsScreenState? collectionsState =
            context.findAncestorStateOfType<_CollectionsScreenState>();
        final shopName = collectionsState?._shopName ?? 'MYBRAND';
        final logoUrl = collectionsState?._logoUrl;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductsPage(
              categoryName: widget.categoryName,
              products: _getDummyProductsForCategory(widget.categoryName),
              shopName: shopName,
              logoUrl: logoUrl,
            ),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          width: isMobile ? 90 : 120, // Adjusted width for desktop
          margin: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: _isHovered
                    ? (Matrix4.identity()..scale(1.05))
                    : Matrix4.identity(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: isMobile ? 80 : 100, // Adjusted width for desktop
                    height: isMobile ? 80 : 100, // Adjusted height for desktop
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC0CB),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.network(
                      widget.imageURL,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.category,
                          size: 40,
                          color: Colors.black.withOpacity(0.7)),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                            child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                          strokeWidth: 2,
                        ));
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.categoryName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: Colors.black,
                  fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDummyProductsForCategory(String category) {
    final List<Map<String, dynamic>> products = [
      {
        'name': 'Diamond Pendant Necklace',
        'price': '24,999',
        'imagePath':
            'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?ixlib=rb-4.0.3',
        'discount': '7% off on making charges',
        'isBestseller': true,
      },
      {
        'name': 'Gold Hoop Earrings',
        'price': '12,500',
        'originalPrice': '15,000',
        'imagePath':
            'https://images.unsplash.com/photo-1630019852942-f89202989a59?ixlib=rb-4.0.3',
        'discount': '5% off on making charges',
      },
      {
        'name': 'Pearl Stud Earrings',
        'price': '8,750',
        'imagePath':
            'https://images.unsplash.com/photo-1611107683227-e9060eccd846?ixlib=rb-4.0.3',
      },
      {
        'name': 'Ruby Cocktail Ring',
        'price': '35,000',
        'imagePath':
            'https://images.unsplash.com/photo-1605100804763-247f67b3557e?ixlib=rb-4.0.3',
        'discount': '10% off on gemstone price',
        'isBestseller': true,
      },
      {
        'name': 'Gold Chain Bracelet',
        'price': '18,999',
        'originalPrice': '21,500',
        'imagePath':
            'https://images.unsplash.com/photo-1611652022419-a9419f74343d?ixlib=rb-4.0.3',
        'discount': '8% off on making charges',
      },
      {
        'name': 'Emerald Statement Necklace',
        'price': '45,000',
        'imagePath':
            'https://images.unsplash.com/photo-1599459183085-9b9f310f471f?ixlib=rb-4.0.3',
        'isBestseller': true,
      },
    ];

    return products;
  }
}
