import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lustra_ai/screens/theme_selection_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:lustra_ai/services/backend_config.dart';
import 'package:lustra_ai/theme/app_theme.dart';
import 'package:lustra_ai/screens/products_page.dart';
import 'package:lustra_ai/screens/add_collection_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
  final WebsiteTheme? theme;
  final bool fromOnboarding;

  const CollectionsScreen({Key? key, this.theme, this.fromOnboarding = false})
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

  @override
  void initState() {
    super.initState();
    _fetchShopDetails();
    if (widget.fromOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateAndUploadPosters();
      });
    }
  }

  Future<void> _generateAndUploadPosters() async {
    print('Starting poster generation...');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user is currently signed in.');
      return;
    }

    final collectionsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('collections')
        .get();

    final collections = collectionsSnapshot.docs;

    print('Found ${collections.length} collections for user ${user.email}.');

    for (var collectionDoc in collections) {
      final collectionData = collectionDoc.data();
      final collectionName = collectionData['name'] as String;
      print('\nProcessing collection: $collectionName');

      try {
        final prompt =
            'Generate a promotional poster for a jewelry collection named "$collectionName". The poster should be visually appealing and represent the essence of a jewelry collection.';

        final url = Uri.parse('$backendBaseUrl/upload_without_image');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'prompt': prompt}),
        );

        if (response.statusCode == 200) {
          final decodedResponse = json.decode(response.body);
          final imageBase64 = decodedResponse['generatedImage'];
          final imageBytes = base64Decode(imageBase64);

          final tempDir = await getTemporaryDirectory();
          final posterFile = File(
              '${tempDir.path}/poster_${collectionName.replaceAll(' ', '_')}.png');
          await posterFile.writeAsBytes(imageBytes);

          final storageRef = FirebaseStorage.instance.ref();
          final posterRef =
              storageRef.child('posters/${user.uid}/$collectionName.png');
          await posterRef.putFile(posterFile);
          final posterUrl = await posterRef.getDownloadURL();

          // Save the poster URL to the collection document
          await collectionDoc.reference.update({'posterUrl': posterUrl});

          print('  - Poster generated and uploaded successfully.');
          print('  - Poster URL: $posterUrl');

          await posterFile.delete();
        } else {
          print('  - Failed to generate poster: ${response.reasonPhrase}');
        }
      } catch (e) {
        print('  - Error processing collection: $e');
      }
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

    Timer? statusTimer;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in.');
      }

      final idToken = await user.getIdToken(true);
      final deployUrl = Uri.parse('https://api-5sqqk2n6ra-uc.a.run.app/deploy');

      final deployResponse = await http.post(
        deployUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      if (deployResponse.statusCode != 200) {
        throw Exception('Failed to trigger deployment: ${deployResponse.body}');
      }

      print('Deployment triggered successfully.');

      // Start polling for deployment status
      const statusUrl = 'https://api-5sqqk2n6ra-uc.a.run.app/deploy-status';
      statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        try {
          final statusResponse = await http.get(
            Uri.parse(statusUrl),
            headers: {
              'Authorization': 'Bearer $idToken',
            },
          );

          if (statusResponse.statusCode == 200) {
            final statusBody = json.decode(statusResponse.body);
            final status = statusBody['status'];
            final conclusion = statusBody['conclusion'];

            print('Deployment Status: $status, Conclusion: $conclusion');

            if (status == 'completed') {
              timer.cancel();
              Navigator.of(context).pop(); // Close loading dialog

              if (conclusion == 'success') {
                const websiteUrl = 'https://test-hw-a51a7.web.app';
                setState(() {
                  _websiteUrl = websiteUrl;
                  _isDeploying = false;
                });

                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Deployment Successful'),
                      content:
                          const Text('Your website is live at: $websiteUrl'),
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
                throw Exception(
                    'Deployment failed with conclusion: $conclusion');
              }
            }
          } else {
            print('Failed to get deployment status: ${statusResponse.body}');
          }
        } catch (e) {
          timer.cancel();
          print('Error checking deployment status: $e');
          Navigator.of(context).pop(); // Close loading dialog on error
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Deployment Status Check Failed'),
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
          setState(() {
            _isDeploying = false;
          });
        }
      });
    } catch (e) {
      statusTimer?.cancel();
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
      setState(() {
        _isDeploying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[CollectionsScreen] Building with shopName: $_shopName');
    isMobile = MediaQuery.of(context).size.width <= 600;
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
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
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Add a modern App Bar inspired by GIVA design
    slivers.add(SliverAppBar(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      floating: true,
      pinned: true,
      elevation: 0,
      leadingWidth: 60,
      // Left hamburger menu
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: IconButton(
          icon: Icon(Icons.menu, color: isDarkMode ? Colors.white : kBlack),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      // Center logo
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AutoSizeText(
              _shopName ?? 'MYBRAND',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  color: isDarkMode ? Colors.white : kBlack,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              minFontSize: 14,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: true,
      // Right icons
      actions: [
        IconButton(
          icon: Icon(Icons.favorite_border,
              color: isDarkMode ? Colors.white : kBlack),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.shopping_bag_outlined,
              color: isDarkMode ? Colors.white : kBlack),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.person_outline,
              color: isDarkMode ? Colors.white : kBlack),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
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
      // HeroCarousel
      SliverToBoxAdapter(
        child: HeroCarousel(
          key: _carouselKey,
          userId: FirebaseAuth.instance.currentUser?.uid,
        ),
      ),
      // Reduce space between banner and categories
      const SliverToBoxAdapter(child: SizedBox(height: 10)),
      // CategoryCarousel
      SliverToBoxAdapter(
        child: CategoryCarousel(userId: FirebaseAuth.instance.currentUser?.uid),
      ),
      // Add the new 'Shop by Recipient' section
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
      const SliverToBoxAdapter(
        child: ShopByRecipientSection(),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 60)),
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
    if (widget.userId == null) return;
    setState(() {
      _collectionsFuture =
          FirestoreService().getCollections(userId: widget.userId);
    });
  }

  @override
  void initState() {
    super.initState();
    print('[HeroCarousel] Initializing with userId: ${widget.userId}');
    if (widget.userId != null) {
      _collectionsFuture =
          FirestoreService().getCollections(userId: widget.userId);
    } else {
      print('[HeroCarousel] userId is null. Not fetching collections.');
      _collectionsFuture = Future.value([]);
    }

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
        print(
            '[HeroCarousel] FutureBuilder connection state: ${snapshot.connectionState}');
        if (snapshot.hasError) {
          print('[HeroCarousel] FutureBuilder error: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          print('[HeroCarousel] FutureBuilder has data: ${snapshot.data}');
        }

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
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.3),
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
    final imageUrl = collection['posterUrl'] ?? collection['bannerUrl'];
    print(
        '[HeroCarousel] Building slide for collection: ${collection['name']}, Image URL: $imageUrl');
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(imageUrl!),
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

class CategoryCarousel extends StatefulWidget {
  final String? userId;

  const CategoryCarousel({Key? key, this.userId}) : super(key: key);

  @override
  _CategoryCarouselState createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<CategoryCarousel> {
  late Future<List<Map<String, String>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _categoriesFuture =
          FirestoreService().getCategories(userId: widget.userId);
    } else {
      _categoriesFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDarkMode ? Colors.black : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Text(
              'Shop By Category',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
          SizedBox(
            height: isMobile ? 130 : 160, // Adjusted height for desktop
            child: FutureBuilder<List<Map<String, String>>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No categories found.'));
                }

                final categories = snapshot.data!;

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    return CategoryItem(
                      categoryName: categories[index]['name']!,
                      imageURL: categories[index]['image'] ??
                          'https://via.placeholder.com/150',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
                      color: Colors.black,
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
      leading: Icon(icon, color: Colors.black),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Colors.black),
      ),
      onTap: () {},
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
    print('[ProductShowcase] Building section header.');
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
                  style: TextStyle(fontSize: MediaQuery.of(context).size.width * 0.07),
                  maxLines: 1,
                  minFontSize: 20),
              const SizedBox(height: 8),
              Text(
                'Curated just for you',
                style: TextStyle(color: Colors.black.withOpacity(0.6)),
              ),
            ],
          )),
          Text('View All →',
              style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.w600)),
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
        width: 280,
        margin: const EdgeInsets.only(right: 24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  widget.product['image']!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product['name']!,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product['price']!,
                    style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
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

class FeaturedStories extends StatelessWidget {
  const FeaturedStories({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80.0, horizontal: 40.0),
      color: Colors.white,
      child: Column(
        children: [
          Text('In the Spotlight', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          Text(
            'Discover the stories behind the sparkle',
            style: TextStyle(color: Colors.black.withOpacity(0.7)),
          ),
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStoryCard(
                'The Artisan\'s Journey',
                'https://via.placeholder.com/400x500/D3C5B3/000000?text=Story+1',
              ),
              _buildStoryCard(
                'Sustainable Sourcing',
                'https://via.placeholder.com/400x500/EAE3D9/000000?text=Story+2',
              ),
              _buildStoryCard(
                'Customer Chronicles',
                'https://via.placeholder.com/400x500/C5A572/FFFFFF?text=Story+3',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCard(String title, String image) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(image, width: 300, height: 400, fit: BoxFit.cover),
        ),
        const SizedBox(height: 24),
        Text(title, style: TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text('Read More →', style: TextStyle(color: Colors.yellow)),
      ],
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 40.0),
      color: Colors.black,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFooterColumn('Shop', ['All', 'Necklaces', 'Rings', 'Gifts']),
              _buildFooterColumn('About Us', ['Our Story', 'Craftsmanship', 'Sustainability']),
              _buildFooterColumn('Support', ['Contact Us', 'FAQ', 'Shipping & Returns']),
              _buildFooterColumn('Follow Us', ['Instagram', 'Facebook', 'Pinterest']),
            ],
          ),
          const SizedBox(height: 60),
          Text(' 2024 MYBRAND. All Rights Reserved.', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white)),
        const SizedBox(height: 24),
        ...links.map((link) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Text(link, style: TextStyle(color: Colors.white.withOpacity(0.7))),
        )),
      ],
    );
  }
}

class ShopByRecipientSection extends StatelessWidget {
  const ShopByRecipientSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Column(
        children: [
          Text(
            'Shop by Recipient',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRecipientCard(
                context,
                'Him',
                'assets/gender/him.jpg',
              ),
              _buildRecipientCard(
                context,
                'Her',
                'assets/gender/her.jpg',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(
      BuildContext context, String title, String imageUrl) {
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
            Image.asset(imageUrl, fit: BoxFit.cover, height: 200),
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
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
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
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
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
