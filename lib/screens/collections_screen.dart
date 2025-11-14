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
import 'package:lustra_ai/screens/edit_footer_screen.dart';
import 'package:lustra_ai/models/footer_data.dart';

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
  final String? shopId;
  final WebsiteTheme? theme;
  final bool fromOnboarding;

  const CollectionsScreen(
      {Key? key, this.shopId, this.theme, this.fromOnboarding = false})
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
  final GlobalKey<_HeroCarouselState> _carouselKey =
      GlobalKey<_HeroCarouselState>();
  final GlobalKey<_CategoryCarouselState> _categoryCarouselKey =
      GlobalKey<_CategoryCarouselState>();

  String? get activeUserId {
    // WEBSITE MODE: shopId passed in URL
    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      return widget.shopId;
    }

    // APP MODE: use FirebaseAuth
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

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
        .doc(activeUserId)
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
    final uid = activeUserId;
    if (uid == null) {
      print("⚠ No userId available for CollectionsScreen.");
      setState(() => _isLoading = false);
      return;
    }

    final firestoreService = FirestoreService();
    final details = await firestoreService.getUserDetailsFor(uid);

    setState(() {
      _shopName = details?['shopName'];
      _logoUrl = details?['logoUrl'];
      _websiteUrl = details?['websiteUrl'];

      final themeStr = details?['theme'];
      _websiteTheme =
          themeStr == 'dark' ? WebsiteTheme.dark : WebsiteTheme.light;

      _isLoading = false;
    });
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
                final websiteUrl =
                    statusBody['url'] ?? 'https://lustra-ai.web.app';
                print(
                    'Website deployed at: $websiteUrl'); // Print URL to console

                setState(() {
                  _websiteUrl = websiteUrl;
                  _isDeploying = false;
                });

                // Save the website URL to Firestore
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(activeUserId)
                      .update({'websiteUrl': websiteUrl});
                }

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
          userId: activeUserId,
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
        child: CategoryCarousel(
          key: _categoryCarouselKey,
          shopName: _shopName,
          logoUrl: _logoUrl,
          userId: activeUserId,
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
      SliverToBoxAdapter(child: ProductShowcase(userId: activeUserId)),
      // const SliverToBoxAdapter(child: ShopByMood()),
      SliverToBoxAdapter(child: FeaturedStoriesSection(userId: activeUserId)),
      // const SliverToBoxAdapter(child: TestimonialsAndSocialProof()),
      SliverToBoxAdapter(child: Footer(activeUserId: activeUserId)),
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

class ProductShowcase extends StatefulWidget {
  final String? userId;
  const ProductShowcase({Key? key, required this.userId}) : super(key: key);

  @override
  _ProductShowcaseState createState() => _ProductShowcaseState();
}

class _ProductShowcaseState extends State<ProductShowcase> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (widget.userId == null) {
      print('[ProductShowcase] No user logged in. Showing dummy products.');
      setState(() {
        _products = _getDummyProducts();
        _isLoading = false;
      });
      return;
    }

    print('[ProductShowcase] Fetching products for user: ${widget.userId}');
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId!)
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      if (snapshot.docs.isNotEmpty) {
        print('[ProductShowcase] User has products. Showing latest 5.');
        final userProducts = snapshot.docs
            .map((doc) => doc.data())
            .toList()
            .cast<Map<String, dynamic>>();

        setState(() {
          _products = userProducts;
          _isLoading = false;
        });
      } else {
        print('[ProductShowcase] No products found. Showing dummy products.');
        setState(() {
          _products = _getDummyProducts();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[ProductShowcase] Error fetching products: $e');
      setState(() {
        _products = _getDummyProducts();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getDummyProducts() {
    return [
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildSectionHeader(context),
        const SizedBox(height: 40),
        SizedBox(
          height: 420, // Adjust height to fit card content
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return ProductCard(product: _products[index]);
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
  final Map<String, dynamic> product;

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
                            widget.product['imagePath'] ??
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
                  Text(widget.product['name']!.toString(),
                      style: kTextTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(widget.product['price']!.toString(),
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

class FeaturedStoriesSection extends StatefulWidget {
  final String? userId;
  const FeaturedStoriesSection({Key? key, this.userId}) : super(key: key);

  @override
  _FeaturedStoriesSectionState createState() => _FeaturedStoriesSectionState();
}

class _FeaturedStoriesSectionState extends State<FeaturedStoriesSection> {
  List<Map<String, String>> _selectedStories = [];

  @override
  void initState() {
    super.initState();
    _fetchBestCollections();
  }

  Future<void> _fetchBestCollections() async {
    final bestCollections =
        await FirestoreService().getBestCollectionsfor(widget.userId);
    if (mounted) {
      setState(() {
        _selectedStories = bestCollections;
      });
    }
  }

  Future<void> _selectFeaturedStories() async {
    final collections =
        await FirestoreService().getCollections(userId: widget.userId);
    final collectionNames = collections.keys.toList();

    if (mounted) {
      final selected = await showDialog<List<String>>(
        context: context,
        builder: (context) =>
            _SelectStoriesDialog(collections: collectionNames),
      );

      if (selected != null && selected.length == 2) {
        final bestCollections = [
          {'name': selected[0], 'image': collections[selected[0]]!},
          {'name': selected[1], 'image': collections[selected[1]]!},
        ];
        await FirestoreService().saveBestCollections(bestCollections);
        setState(() {
          _selectedStories = bestCollections;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 20.0),
      child: Column(
        children: [
          Text(
            'BEST COLLECTIONS',
            style: GoogleFonts.lato(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectFeaturedStories,
            child: const Text('Select Best Collections'),
          ),
          const SizedBox(height: 40),
          StoryBanner(stories: _selectedStories),
        ],
      ),
    );
  }
}

class _SelectStoriesDialog extends StatefulWidget {
  final List<String> collections;

  const _SelectStoriesDialog({Key? key, required this.collections})
      : super(key: key);

  @override
  __SelectStoriesDialogState createState() => __SelectStoriesDialogState();
}

class __SelectStoriesDialogState extends State<_SelectStoriesDialog> {
  final List<String> _selected = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select 2 best collections'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.collections.length,
          itemBuilder: (context, index) {
            final collectionName = widget.collections[index];
            final isSelected = _selected.contains(collectionName);
            return CheckboxListTile(
              title: Text(collectionName),
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    if (_selected.length < 2) {
                      _selected.add(collectionName);
                    }
                  } else {
                    _selected.remove(collectionName);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_selected.length == 2) {
              Navigator.of(context).pop(_selected);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Please select exactly 2 collections.')),
              );
            }
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class StoryBanner extends StatelessWidget {
  final List<Map<String, String>> stories;

  const StoryBanner({Key? key, required this.stories}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return const Center(child: Text('No collection selected.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
        double aspectRatio = 16 / 9;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            return StoryCard(
              title: stories[index]['name']!,
              imageUrl: stories[index]['image']!,
            );
          },
        );
      },
    );
  }
}

class StoryCard extends StatefulWidget {
  final String title;
  final String imageUrl;

  const StoryCard({Key? key, required this.title, required this.imageUrl})
      : super(key: key);

  @override
  _StoryCardState createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.error)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.lora(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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

class Footer extends StatefulWidget {
  final String? activeUserId;
  const Footer({Key? key, this.activeUserId}) : super(key: key);

  @override
  _FooterState createState() => _FooterState();
}

class _FooterState extends State<Footer> {
  Map<String, List<String>> _footerData = {};

  @override
  void initState() {
    super.initState();
    _fetchFooterData();
  }

  Future<void> _fetchFooterData() async {
    if (widget.activeUserId == null) return;
    final firestoreService = FirestoreService();
    final footerData =
        await firestoreService.getFooterData(widget.activeUserId!);
    setState(() {
      _footerData = footerData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _websiteTheme == WebsiteTheme.dark ? Colors.white : Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () {
              final List<FooterColumnData> footerData =
                  _footerData.entries.map((entry) {
                return FooterColumnData(title: entry.key, links: entry.value);
              }).toList();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      EditFooterScreen(footerData: footerData),
                ),
              );
            },
            child: const Text('Edit Footer'),
          ),
          const SizedBox(height: 20),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            flex: 2,
            child: _FooterColumn(
                title: 'About', links: _footerData['About'] ?? [])),
        Expanded(
            flex: 2,
            child:
                _FooterColumn(title: 'Shop', links: _footerData['Shop'] ?? [])),
        Expanded(
            flex: 2,
            child: _FooterColumn(
                title: 'Customer Care',
                links: _footerData['Customer Care'] ?? [])),
        Expanded(flex: 3, child: _ConnectColumn()),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterColumn(title: 'About', links: _footerData['About'] ?? []),
        SizedBox(height: 40),
        _FooterColumn(title: 'Shop', links: _footerData['Shop'] ?? []),
        SizedBox(height: 40),
        _FooterColumn(
            title: 'Customer Care', links: _footerData['Customer Care'] ?? []),
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

class _ConnectColumn extends StatefulWidget {
  const _ConnectColumn({Key? key}) : super(key: key);

  @override
  __ConnectColumnState createState() => __ConnectColumnState();
}

class __ConnectColumnState extends State<_ConnectColumn> {
  String? _shopAddress;

  @override
  void initState() {
    super.initState();
    _fetchShopAddress();
  }

  Future<void> _fetchShopAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()!.containsKey('shopAddress')) {
        if (mounted) {
          setState(() {
            _shopAddress = doc.data()!['shopAddress'];
          });
        }
      }
    }
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: _websiteTheme == WebsiteTheme.dark
                ? Colors.black
                : Colors.white,
            width: 1.5),
      ),
      child: Icon(icon,
          size: 24,
          color:
              _websiteTheme == WebsiteTheme.dark ? Colors.black : Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect With Us',
            style: kTextTheme.headlineSmall?.copyWith(
                fontSize: 20,
                color: _websiteTheme == WebsiteTheme.dark
                    ? Colors.black
                    : Colors.white)),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildSocialIcon(Icons.facebook),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.camera_alt),
            const SizedBox(width: 16),
            _buildSocialIcon(Icons.video_call),
          ],
        ),
        if (_shopAddress != null && _shopAddress!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Text(
              _shopAddress!,
              style: kTextTheme.bodyLarge?.copyWith(
                  color: _websiteTheme == WebsiteTheme.dark
                      ? Colors.black
                      : Colors.white),
            ),
          ),
      ],
    );
  }
}

class CategoryCarousel extends StatefulWidget {
  final String? shopName;
  final String? logoUrl;
  final String? userId;

  const CategoryCarousel({Key? key, this.shopName, this.logoUrl, this.userId})
      : super(key: key);

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
    if (widget.userId == null) return;
    print('[CategoryCarousel] Loading categories...');
    try {
      final firestoreService = FirestoreService();
      final categories =
          await firestoreService.getUserCategoriesFor(widget.userId!);

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
                  name: categoryName,
                  imageUrl: imageUrl,
                  shopName: widget.shopName,
                  logoUrl: widget.logoUrl,
                  userId: widget.userId,
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
            mainAxisAlignment: MainAxisAlignment.center,
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
    return Container(
      width: isMobile ? 150 : 300,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Image.asset(imageUrl, fit: BoxFit.cover, height: 150),
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
  final String name;
  final String imageUrl;
  final String? shopName;
  final String? logoUrl;
  final String? userId;

  const CategoryItem({
    Key? key,
    required this.name,
    required this.imageUrl,
    this.shopName,
    this.logoUrl,
    this.userId,
  }) : super(key: key);

  @override
  _CategoryItemState createState() => _CategoryItemState();
}

class _CategoryItemState extends State<CategoryItem> {
  bool _isHovered = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final products = await _firestoreService.getProductsForCategoryfor(
            widget.userId, widget.name);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ProductsPage(
            categoryName: widget.name,
            products: products,
            shopName: widget.shopName,
            logoUrl: widget.logoUrl,
            websiteTheme: _websiteTheme,
          ),
        ));
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
                        imageUrl: widget.imageUrl,
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
                widget.name,
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
}
