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
import 'package:lustra_ai/screens/products_page.dart';
import 'package:lustra_ai/screens/add_collection_screen.dart';
import 'package:lustra_ai/screens/delete_collection_screen.dart';
import 'package:lustra_ai/screens/add_category_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- Theme and Styling Constants ---
var _websiteTheme = WebsiteTheme.light;
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
  // WebsiteTheme _websiteTheme = WebsiteTheme.light; // Default to light theme
  final GlobalKey<_HeroCarouselState> _carouselKey = GlobalKey<_HeroCarouselState>();
  final GlobalKey<_CategoryCarouselState> _categoryCarouselKey = GlobalKey<_CategoryCarouselState>();

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
      final themeStr = details['theme'] as String?;
      setState(() {
        _shopName = details['shopName'];
        _logoUrl = details['logoUrl'];
        _websiteUrl = details['websiteUrl']; // Fetch the website URL
        if (themeStr == 'dark') {
          _websiteTheme = WebsiteTheme.dark;
        } else {
          _websiteTheme = WebsiteTheme.light;
        }
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

    final isDarkMode = _websiteTheme == WebsiteTheme.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
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
    final bool isDarkMode = _websiteTheme == WebsiteTheme.dark;

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

    // Add the rest of the content
    slivers.addAll([
      // HeroCarousel
      SliverToBoxAdapter(
        child: HeroCarousel(
          key: _carouselKey,
          userId: FirebaseAuth.instance.currentUser?.uid,
        ),
      ),
      SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddCollectionScreen(),
                  ),
                );
                if (result == true) {
                  _carouselKey.currentState?.refreshCollections();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DeleteCollectionScreen(),
                  ),
                );
                if (result == true) {
                  _carouselKey.currentState?.refreshCollections();
                }
              },
            ),
          ],
        ),
      ),
      // Reduce space between banner and categories
      const SliverToBoxAdapter(child: SizedBox(height: 10)),
      // CategoryCarousel
      SliverToBoxAdapter(
        child: CategoryCarousel(key: _categoryCarouselKey),
      ),
      SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(Icons.add_circle_outline,
                  color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddCategoryScreen(),
                  ),
                );
                if (result == true) {
                  _categoryCarouselKey.currentState?.refreshCategories();
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  color: isDarkMode ? Colors.white : Colors.black),
              onPressed: () async {
                // TODO: Implement delete category functionality
              },
            ),
          ],
        ),
      ),
      // Add the new 'Shop by Recipient' section
      const SliverToBoxAdapter(child: SizedBox(height: 40)),
      const SliverToBoxAdapter(
        child: ShopByRecipientSection(),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 60)),
      const SliverToBoxAdapter(child: ProductShowcase()),
      // const SliverToBoxAdapter(child: ShopByMood()),
      const SliverToBoxAdapter(child: FeaturedStories()),
      // const SliverToBoxAdapter(child: TestimonialsAndSocialProof()),
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
  late Future<Map<String, String>> _collectionsFuture;
  Timer? _autoPlayTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;

  void refreshCollections() {
    if (widget.userId == null) return;
    print('[HeroCarousel] Refreshing collections...');
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
      _collectionsFuture = Future.value({});
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

    return FutureBuilder<Map<String, String>>(
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
            aspectRatio: 16 / 9,
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
        final listCollections = collections.keys.toList();
        return Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9, // Updated aspect ratio
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  print('[HeroCarousel] Page changed to index: $index');
                  setState(() {
                    _current = index;
                    _animationController.reset();
                    _animationController.forward();
                  });
                },
                itemCount: collections.length,
                itemBuilder: (context, index) {
                  final collectionName = collections.keys.elementAt(index);
                  final imageUrl = collections[collectionName];
                  return _buildBannerSlide(
                      collectionName, imageUrl ?? '', isMobile);
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: collections.entries.map((entry) {
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      listCollections.indexOf(entry.key),
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
                      color: _current == listCollections.indexOf(entry.key)
                          ? _websiteTheme == WebsiteTheme.dark
                              ? Colors.white
                              : Colors.black
                          : _websiteTheme == WebsiteTheme.dark
                              ? Colors.grey
                              : Colors.grey,
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

  Widget _buildBannerSlide(
      String collectionName, String imageUrl, bool isMobile) {
    print(
        '[HeroCarousel] Building slide for collection: $collectionName, Image URL: $imageUrl');
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(),
          ),
          errorWidget: (context, url, error) => const Center(
            child: Icon(Icons.error, color: Colors.red),
          ),
        ),
        Container(
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
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05,
            vertical: MediaQuery.of(context).size.width * 0.05,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _animation,
                child: Text(
                  collectionName,
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
      ],
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
                  style: kTextTheme.displayLarge?.copyWith(
                      fontSize: MediaQuery.of(context).size.width * 0.07,
                      color: Theme.of(context).colorScheme.onSurface),
                  maxLines: 1,
                  minFontSize: 20),
              const SizedBox(height: 8),
              Text(
                'Curated just for you',
                style: kTextTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: MediaQuery.of(context).size.width * 0.04),
              ),
            ],
          )),
          Text('View All →',
              style: kTextTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600)),
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
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: _isHovered
                        ? (Matrix4.identity()..scale(1.05))
                        : Matrix4.identity(),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC0CB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Image.network(
                            widget.product['image']!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.category, size: 40),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          ),
                        ),
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
              decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
            ),
            Container(
                height: 400,
                decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4))),
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
    final textColor = isOverlay
        ? Theme.of(context).colorScheme.inversePrimary
        : Theme.of(context).colorScheme.onSurface;
    final subtitleColor = isOverlay
        ? Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8)
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.7);

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: _websiteTheme == WebsiteTheme.dark ? Colors.white : Colors.black,
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
                Text(' 2024 Lustra. All Rights Reserved.',
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
                Text(' 2024 Lustra. All Rights Reserved.',
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
            style: kTextTheme.headlineSmall?.copyWith(
                fontSize: 20,
                color: _websiteTheme == WebsiteTheme.dark
                    ? Colors.black
                    : Colors.white),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          widget.text,
          style: kTextTheme.bodyLarge?.copyWith(
            color: _websiteTheme == WebsiteTheme.dark
                ? Colors.black
                : Colors.white,
          ),
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
                      style: kTextTheme.bodyLarge
                          ?.copyWith(color: Colors.white, fontSize: 14)),
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

class CategoryCarousel extends StatefulWidget {
  const CategoryCarousel({Key? key}) : super(key: key);

  @override
  _CategoryCarouselState createState() => _CategoryCarouselState();
}

class _CategoryCarouselState extends State<CategoryCarousel> {
  Map<String, dynamic> _categories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void refreshCategories() {
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    print('[CategoryCarousel] Loading categories...');
    try {
      final firestoreService = FirestoreService();
      final categories = await firestoreService.getUserCategories();

      print('[CategoryCarousel] Categories loaded: $categories');

      if (mounted) {
        setState(() {
          _categories = categories ?? {};
          _isLoading = false;
        });
      }
    } catch (e, st) {
      print('[CategoryCarousel] Error while loading categories: $e');
      print(st);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return const Center(child: Text('No categories found.'));
    }

    return Container(
      color: _websiteTheme == WebsiteTheme.dark ? Colors.black : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24.0),
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
                color: _websiteTheme == WebsiteTheme.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          SizedBox(
            height: isMobile ? 130 : 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final categoryName = _categories.keys.elementAt(index);
                final imageUrl = _categories[categoryName];
                if (imageUrl == null) {
                  // Return a placeholder or an empty container if the URL is null
                  return const SizedBox.shrink();
                }
                print("Image URL for $categoryName: $imageUrl");
                print("The Image URL is $imageUrl");
                return CategoryItem(
                  categoryName: categoryName,
                  imageURL: imageUrl,
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      color: _websiteTheme == WebsiteTheme.dark ? Colors.black : Colors.white,
      child: Column(
        children: [
          Text(
            'Shop by Recipient',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white
                  : Colors.black,
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
                      fontSize: isMobile ? 10 : 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios,
                      color: Colors.white, size: 16),
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
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC0CB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: widget.imageURL,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.category, size: 40),
                      ),
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
                  color: _websiteTheme == WebsiteTheme.dark
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
