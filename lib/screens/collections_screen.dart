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
import 'package:lustra_ai/screens/contact_us_screen.dart';
import 'package:lustra_ai/models/footer_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- Theme and Styling Constants / Design System ---

var _websiteTheme = WebsiteTheme.light;
const Color kOffWhite = Color(0xFFF8F7F4);
const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);
bool isMobile = false;

/// Simple design system tokens to keep things consistent
class AppDS {
  // Palette
  static const Color bgLight = Color(0xFFF8F7F4);
  static const Color bgDark = Color(0xFF080808);
  static const Color gold = kGold;
  static const Color black = kBlack;
  static const Color white = Colors.white;
  static const Color grey = Color(0xFF8C8C8C);

  // Spacing
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double spaceXxl = 48;

  // Radius
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(16));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(24));

  // Shadow
  static const BoxShadow softShadow = BoxShadow(
    color: Colors.black12,
    blurRadius: 18,
    offset: Offset(0, 10),
  );

  // Typography
  static TextStyle get h1 => GoogleFonts.playfairDisplay(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: black,
      );

  static TextStyle get h2 => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: black,
      );

  static TextStyle get sectionLabel => GoogleFonts.lato(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: grey,
      );

  static TextStyle get body => GoogleFonts.lato(
        fontSize: 15,
        height: 1.5,
        color: black,
      );

  static TextStyle get bodyMuted => GoogleFonts.lato(
        fontSize: 14,
        height: 1.5,
        color: grey,
      );

  static TextStyle get button => GoogleFonts.lato(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: white,
      );
}

final TextTheme kTextTheme = TextTheme(
  displayLarge:
      AppDS.h1, // large headline (e.g., New Arrivals title, hero text)
  headlineSmall: AppDS.h2,
  bodyLarge: AppDS.body,
  bodyMedium: AppDS.bodyMuted,
  labelLarge: AppDS.button,
);

TextStyle sectionHeadingStyle(BuildContext context) {
  final bool isDark = _websiteTheme == WebsiteTheme.dark;
  final width = MediaQuery.of(context).size.width;

  return AppDS.sectionLabel.copyWith(
    color: _websiteTheme == WebsiteTheme.dark ? Colors.white70 : Colors.black54,
  );
}

TextStyle subheadingStyle() {
  final bool isDark = _websiteTheme == WebsiteTheme.dark;

  return GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: isDark ? Colors.white : Colors.black,
  );
}

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
  final List<Map<String, String>> topNavItems = [
    {"label": "Collections", "value": "collections"},
    {"label": "Categories", "value": "categories"},
    {"label": "Him", "value": "Him"},
    {"label": "Her", "value": "Her"},
  ];

  // 🔹 New: data for mega menus
  Map<String, String> _collections = {}; // collectionName -> bannerUrl
  List<String> _categoryNames = [];
  bool _isHoveringNav = false;
  bool _isHoveringMegaMenu = false;

  // 🔹 New: which mega menu is open on web ('collections', 'categories', 'Him', 'Her')
  String? _activeMegaMenuKey;

  String? _shopName;
  String? _logoUrl;
  String? _websiteUrl;
  bool _isDeploying = false;
  bool _isLoading = true;

  final GlobalKey<_HeroCarouselState> _carouselKey =
      GlobalKey<_HeroCarouselState>();
  final GlobalKey<_CategoryCarouselState> _categoryCarouselKey =
      GlobalKey<_CategoryCarouselState>();

  String? get activeUserId {
    if (widget.shopId != null && widget.shopId!.isNotEmpty) {
      return widget.shopId;
    }
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  @override
  void initState() {
    super.initState();
    _fetchShopDetails();
    _loadMegaMenuData(); // 🔹 also load collections + categories for mega menus

    if (widget.fromOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateAndUploadPosters();
      });
    }
  }

  void _scheduleMenuClose() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_isHoveringNav && !_isHoveringMegaMenu) {
        if (mounted) {
          setState(() => _activeMegaMenuKey = null);
        }
      }
    });
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

  /// 🔹 New: load collections + categories for mega menus
  Future<void> _loadMegaMenuData() async {
    final uid = activeUserId;
    if (uid == null) return;

    try {
      final firestoreService = FirestoreService();
      final collections = await firestoreService.getCollections(userId: uid);
      final categoriesMap = await firestoreService
          .getUserCategoriesFor(uid); // Map<String, dynamic>

      setState(() {
        _collections = collections;
        _categoryNames = categoriesMap.keys.map((e) => e.toString()).toList()
          ..sort();
      });
    } catch (e, st) {
      print('[MegaMenu] Error loading data: $e');
      print(st);
    }
  }

  Future<void> _deployWebsite() async {
    setState(() {
      _isDeploying = true;
    });

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
                print('Website deployed at: $websiteUrl');

                setState(() {
                  _websiteUrl = websiteUrl;
                  _isDeploying = false;
                });

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
          Navigator.of(context).pop();
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
      Navigator.of(context).pop();
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

  void _onNavItemSelected(String value) async {
    // ⚠️ For now we keep existing behaviour when clicked.
    if (value == "Him" || value == "Her") {
      if (activeUserId == null) return;
      final products =
          await FirestoreService().getProductsForGender(activeUserId!, value);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ProductsPage(
          userId: activeUserId!,
          categoryName: value,
          products: products,
          shopName: _shopName,
          logoUrl: _logoUrl,
          websiteTheme: _websiteTheme,
        ),
      ));
    } else if (value == "Collections") {
      _carouselKey.currentState?.refreshCollections();
      if (_carouselKey.currentContext != null) {
        Scrollable.ensureVisible(_carouselKey.currentContext!);
      }
    } else if (value == "Categories") {
      _categoryCarouselKey.currentState?.refreshCategories();
      if (_categoryCarouselKey.currentContext != null) {
        Scrollable.ensureVisible(_categoryCarouselKey.currentContext!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[CollectionsScreen] Building with shopName: $_shopName');
    isMobile = MediaQuery.of(context).size.width <= 600;
    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            _websiteTheme == WebsiteTheme.dark ? AppDS.bgDark : AppDS.bgLight,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDarkMode = _websiteTheme == WebsiteTheme.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? AppDS.bgDark : AppDS.bgLight,
      drawer: AppDrawer(
        shopName: _shopName,
        userId: widget.shopId,
        topNavItems: topNavItems,
        onNavSelected: _onNavItemSelected,
        collections: _collections, // 🔹 pass to drawer
        categories: _categoryNames, // 🔹 pass to drawer
      ),
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

    // ───────────────────────────── SliverAppBar ─────────────────────────────
    slivers.add(
      SliverAppBar(
        backgroundColor: isDarkMode ? AppDS.bgDark : Colors.white,
        floating: true,
        pinned: true,
        elevation: 0,
        leadingWidth: 56,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu_rounded,
                color: isDarkMode ? Colors.white : AppDS.black),
            onPressed: () {
              Scaffold.of(ctx).openDrawer();
            },
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_logoUrl != null && _logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: CachedNetworkImageProvider(_logoUrl!),
                  backgroundColor: Colors.transparent,
                ),
              ),
            Flexible(
              child: AutoSizeText(
                _shopName ?? 'YOUR BRAND',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDarkMode ? Colors.white : AppDS.black,
                ),
                maxLines: 1,
                minFontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          if (!isMobile)
            ...topNavItems.map((item) {
              final value = item["value"]!;
              final label = item["label"]!;
              final bool isActive = _activeMegaMenuKey == value;

              return MouseRegion(
                onEnter: (_) {
                  _isHoveringNav = true;
                  setState(() {
                    _activeMegaMenuKey = value;
                  });
                },
                onExit: (_) {
                  _isHoveringNav = false;
                  _scheduleMenuClose();
                },
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _activeMegaMenuKey = isActive ? null : value;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isDarkMode ? Colors.white : AppDS.black,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          IconButton(
            icon: Icon(Icons.favorite_border,
                size: 22, color: isDarkMode ? Colors.white : AppDS.black),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.shopping_bag_outlined,
                size: 22, color: isDarkMode ? Colors.white : AppDS.black),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
    );

    // ───────────────────────── Mega Menu (WEB only) ─────────────────────────
    if (!isMobile && _activeMegaMenuKey != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: MouseRegion(
            onEnter: (_) {
              _isHoveringMegaMenu = true;
            },
            onExit: (_) {
              _isHoveringMegaMenu = false;
              _scheduleMenuClose();
            },
            child: _buildActiveMegaMenu(isDarkMode),
          ),
        ),
      );
    }

    // ───────────────────────── Rest of the page (unchanged) ─────────────────
    slivers.addAll([
      // HERO BANNER
      SliverToBoxAdapter(
        child: isMobile
            ? HeroCarousel(
                key: _carouselKey,
                userId: activeUserId,
                shopName: _shopName,
                logoUrl: _logoUrl,
              )
            : Padding(
                padding: const EdgeInsets.only(
                  left: 120.0,
                  right: 120.0,
                  top: 16.0,
                  bottom: 40.0,
                ),
                child: HeroCarousel(
                  key: _carouselKey,
                  userId: activeUserId,
                  shopName: _shopName,
                  logoUrl: _logoUrl,
                ),
              ),
      ),

      if (!kIsWeb)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Add Collection',
                      icon: Icon(Icons.add_circle_outline,
                          color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AddCollectionScreen(),
                          ),
                        );
                        if (result == true) {
                          _carouselKey.currentState?.refreshCollections();
                          _loadMegaMenuData();
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete Collection',
                      icon: Icon(Icons.remove_circle_outline,
                          color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const DeleteCollectionScreen(),
                          ),
                        );
                        if (result == true) {
                          _carouselKey.currentState?.refreshCollections();
                          _loadMegaMenuData();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // CATEGORY CAROUSEL
      SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CategoryCarousel(
                key: _categoryCarouselKey,
                shopName: _shopName,
                logoUrl: _logoUrl,
                userId: activeUserId,
              ),
            ),
          ),
        ),
      ),

      if (!kIsWeb)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Add Category',
                      icon: Icon(Icons.add_circle_outline,
                          color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () async {
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AddCategoryScreen(),
                          ),
                        );
                        if (result == true) {
                          _categoryCarouselKey.currentState
                              ?.refreshCategories();
                          _loadMegaMenuData();
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete Category (coming soon)',
                      icon: Icon(Icons.remove_circle_outline,
                          color: isDarkMode ? Colors.white : Colors.black),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),

      SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ShopByRecipientSection(
              userId: activeUserId,
              shopName: _shopName,
              logoUrl: _logoUrl,
            ),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),

      SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ProductShowcase(userId: activeUserId),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),

      SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: FeaturedCollectionsShowcase(userId: activeUserId),
          ),
        ),
      ),

      SliverToBoxAdapter(
        child: Footer(
          activeUserId: activeUserId,
          shopName: _shopName,
          logoUrl: _logoUrl,
          websiteTheme: _websiteTheme,
        ),
      ),
    ]);

    return slivers;
  }

  // ───────────────────── Mega menu builders ─────────────────────

  Widget _buildActiveMegaMenu(bool isDarkMode) {
    switch (_activeMegaMenuKey) {
      case 'collections':
        return _buildCollectionsMegaMenu(isDarkMode);
      case 'categories':
      case 'Him':
      case 'Her':
        return _buildCategoriesMegaMenu(
          _activeMegaMenuKey!,
          isDarkMode,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Collections Mega Menu:
  /// Shows all collections, and under each collection shows ALL categories
  Widget _buildCollectionsMegaMenu(bool isDarkMode) {
    if (_collections.isEmpty && _categoryNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      child: Container(
        width: double.infinity,
        color: isDarkMode ? AppDS.bgDark : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collections',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppDS.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _activeMegaMenuKey = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _collections.keys.map((collectionName) {
                  return Container(
                    width: 220,
                    margin: const EdgeInsets.only(right: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collectionName,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._categoryNames.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                              cat,
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Categories / Him / Her Mega Menu:
  /// All of them simply show ALL categories for now.
  Widget _buildCategoriesMegaMenu(String title, bool isDarkMode) {
    if (_categoryNames.isEmpty) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      child: Container(
        width: double.infinity,
        color: isDarkMode ? AppDS.bgDark : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppDS.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _activeMegaMenuKey = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: _categoryNames.map((cat) {
                return Chip(
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  label: Text(
                    cat,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  backgroundColor:
                      isDarkMode ? Colors.white10 : Colors.grey.shade100,
                  side: BorderSide(
                    color: isDarkMode ? Colors.white24 : Colors.grey.shade300,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Reusable Modular Widgets ---

class HeroCarousel extends StatefulWidget {
  final String? userId;
  final String? shopName;
  final String? logoUrl;

  const HeroCarousel({Key? key, this.userId, this.shopName, this.logoUrl})
      : super(key: key);

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

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
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
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) {
        if (_current < (itemCount - 1)) {
          _pageController.animateToPage(
            _current + 1,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
          );
        } else {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobileLocal = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<Map<String, String>>(
      future: _collectionsFuture,
      builder: (context, snapshot) {
        print(
            '[HeroCarousel] FutureBuilder connection state: ${snapshot.connectionState}');
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
        _startAutoPlay(collections.length);
        final listCollections = collections.keys.toList();

        return Column(
          children: [
            AspectRatio(
              aspectRatio: isMobileLocal ? 16 / 9 : 21 / 9,
              child: ClipRRect(
                borderRadius:
                    isMobileLocal ? BorderRadius.zero : AppDS.radiusLg,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    print('[HeroCarousel] Page changed to index: $index');
                    setState(() {
                      _current = index;
                      _animationController
                        ..reset()
                        ..forward();
                    });
                  },
                  itemCount: collections.length,
                  itemBuilder: (context, index) {
                    final collectionName = collections.keys.elementAt(index);
                    final imageUrl = collections[collectionName];
                    return GestureDetector(
                      onTap: () async {
                        if (widget.userId == null) return;
                        final products =
                            await FirestoreService().getProductsForCollection(
                          widget.userId,
                          collectionName,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductsPage(
                              userId: widget.userId!,
                              categoryName: collectionName,
                              products: products,
                              shopName: widget.shopName,
                              logoUrl: widget.logoUrl,
                            ),
                          ),
                        );
                      },
                      child: _buildBannerSlide(
                        collectionName,
                        imageUrl ?? '',
                        isMobileLocal,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: collections.entries.map((entry) {
                final idx = listCollections.indexOf(entry.key);
                final bool isActive = _current == idx;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: isActive ? 22.0 : 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isActive
                          ? kGold
                          : (_websiteTheme == WebsiteTheme.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade400),
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
      String collectionName, String imageUrl, bool isMobileLocal) {
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
                Colors.black.withOpacity(0.7),
                Colors.black.withOpacity(0.2),
                Colors.transparent,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: MediaQuery.of(context).size.width * 0.06,
            right: MediaQuery.of(context).size.width * 0.06,
            bottom:
                isMobileLocal ? 18 : MediaQuery.of(context).size.height * 0.05,
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _animation,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobileLocal ? double.infinity : 480,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isMobileLocal
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(
                        collectionName,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isMobileLocal ? 24 : 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Handcrafted pieces for every moment.',
                      textAlign:
                          isMobileLocal ? TextAlign.center : TextAlign.left,
                      style: GoogleFonts.lato(
                        fontSize: isMobileLocal ? 12.5 : 15,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: isMobileLocal ? 12 : 18),
                    ElevatedButton(
                      onPressed: () async {
                        if (widget.userId == null) return;
                        final products =
                            await FirestoreService().getProductsForCollection(
                          widget.userId,
                          collectionName,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductsPage(
                              userId: widget.userId!,
                              categoryName: collectionName,
                              products: products,
                              shopName: widget.shopName,
                              logoUrl: widget.logoUrl,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGold,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobileLocal ? 18 : 24,
                          vertical: isMobileLocal ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Explore Collection',
                        style: GoogleFonts.lato(
                          fontSize: isMobileLocal ? 12 : 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}

// Drawer

class AppDrawer extends StatelessWidget {
  final String? shopName;
  final String? userId;
  final List<Map<String, String>> topNavItems;
  final Function(String) onNavSelected;

  // 🔹 New: data for mega menu-style items on mobile
  final Map<String, String> collections; // collectionName -> bannerUrl
  final List<String> categories;

  const AppDrawer({
    Key? key,
    this.userId,
    this.shopName,
    required this.topNavItems,
    required this.onNavSelected,
    this.collections = const {},
    this.categories = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName != null && shopName!.isNotEmpty
                        ? shopName!
                        : 'My Store',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      color: kBlack,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  const Divider(),
                ],
              ),
            ),

            // 🔹 Mega Menu style sections in Drawer
            _buildCollectionsDrawerMega(context),
            _buildCategoriesDrawerMega(context, 'Categories'),
            _buildCategoriesDrawerMega(context, 'Him'),
            _buildCategoriesDrawerMega(context, 'Her'),

            const Divider(),
            _buildDrawerItem('Home', Icons.home_outlined),
            _buildDrawerItem('My Orders', Icons.shopping_bag_outlined),
            _buildDrawerItem('Wishlist', Icons.favorite_border),
            _buildDrawerItem('My Account', Icons.person_outline),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ContactUsScreen(userId: userId),
                ),
              ),
              child: _buildDrawerItem('Contact Us', Icons.support_agent),
            ),
            _buildDrawerItem('FAQs', Icons.help_outline),
          ],
        ),
      ),
    );
  }

  // ───────────────────── Drawer mega: Collections ─────────────────────
  Widget _buildCollectionsDrawerMega(BuildContext context) {
    if (collections.isEmpty && categories.isEmpty) {
      // fallback to simple tile
      return ListTile(
        leading: const Icon(Icons.grid_view, color: kBlack, size: 20),
        title: Text(
          'Collections',
          style: GoogleFonts.lato(fontSize: 15, color: kBlack),
        ),
        onTap: () {
          Navigator.pop(context);
          onNavSelected('collections');
        },
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.grid_view, color: kBlack, size: 20),
      title: Text(
        'Collections',
        style: GoogleFonts.lato(fontSize: 15, color: kBlack),
      ),
      children: collections.keys.map((collectionName) {
        return Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0, right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                collectionName,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kBlack,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: categories.map((cat) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.lato(fontSize: 12, color: kBlack),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ───────────────────── Drawer mega: Categories / Him / Her ─────────────────────
  Widget _buildCategoriesDrawerMega(BuildContext context, String title) {
    if (categories.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.label_outline, color: kBlack, size: 20),
        title: Text(
          title,
          style: GoogleFonts.lato(fontSize: 15, color: kBlack),
        ),
        onTap: () {
          // we will wire this in next step
          Navigator.pop(context);
        },
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.label_outline, color: kBlack, size: 20),
      title: Text(
        title,
        style: GoogleFonts.lato(fontSize: 15, color: kBlack),
      ),
      children: categories.map((cat) {
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 56, right: 16),
          title: Text(
            cat,
            style: GoogleFonts.lato(fontSize: 14, color: kBlack),
          ),
          onTap: () {
            // 👇 We'll connect navigation logic in the next step.
            // For now it's just visual.
          },
        );
      }).toList(),
    );
  }

  Widget _buildDrawerItem(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: kBlack, size: 20),
      title: Text(
        title,
        style: GoogleFonts.lato(fontSize: 15, color: kBlack),
      ),
      onTap: () {},
    );
  }
}

// --- Product Showcase ---

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(context),
        const SizedBox(height: 28),
        SizedBox(
          height: 380,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'NEW ARRIVALS',
            style: sectionHeadingStyle(context),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                  child: Text(
                'Curated just for you',
                style: subheadingStyle(),
              )),
              Text('View All →',
                  style: kTextTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================
// NEW FEATURED COLLECTIONS SHOWCASE (Alternating Luxury Layout)
// ===========================================================

class FeaturedCollectionsShowcase extends StatefulWidget {
  final String? userId;
  const FeaturedCollectionsShowcase({Key? key, this.userId}) : super(key: key);

  @override
  State<FeaturedCollectionsShowcase> createState() =>
      _FeaturedCollectionsShowcaseState();
}

class _FeaturedCollectionsShowcaseState
    extends State<FeaturedCollectionsShowcase> {
  List<Map<String, String>> featured = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await FirestoreService().getBestCollectionsfor(widget.userId);
    if (mounted) {
      setState(() {
        featured = items;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (featured.isEmpty) {
      return const SizedBox(
          height: 80,
          child: Center(child: Text("No featured collections added yet.")));
    }

    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("FEATURED COLLECTIONS", style: sectionHeadingStyle(context)),
          const SizedBox(height: 30),

          // Alternating Layout Loop
          Column(
            children: List.generate(featured.length, (index) {
              final item = featured[index];
              final image = item["image"]!;
              final title = item["name"]!;
              final bool reverseRow = index % 2 == 1;

              final bigImageWidget = _BigImageCard(imageUrl: image);
              final descriptionCard = _DescriptionCard(
                title: title,
                description:
                    "Introducing our exquisite $title collection — crafted with precision, grace, and an eye for timeless beauty. Each piece reflects a unique narrative designed to elevate your finest moments with elegance that speaks louder than words.",
              );

              if (isMobile) {
                return Column(
                  children: [
                    bigImageWidget,
                    const SizedBox(height: 18),
                    descriptionCard,
                    const SizedBox(height: 36),
                  ],
                );
              }

              return Row(
                children: reverseRow
                    ? [
                        Expanded(child: descriptionCard),
                        const SizedBox(width: 28),
                        Expanded(child: bigImageWidget),
                      ]
                    : [
                        Expanded(child: bigImageWidget),
                        const SizedBox(width: 28),
                        Expanded(child: descriptionCard),
                      ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// BIG IMAGE CARD
class _BigImageCard extends StatefulWidget {
  final String imageUrl;
  const _BigImageCard({required this.imageUrl});

  @override
  State<_BigImageCard> createState() => _BigImageCardState();
}

class _BigImageCardState extends State<_BigImageCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        transform:
            hover ? (Matrix4.identity()..scale(1.03)) : Matrix4.identity(),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                    imageUrl: widget.imageUrl, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(.55),
                        Colors.transparent
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// DESCRIPTION CARD
class _DescriptionCard extends StatelessWidget {
  final String title;
  final String description;

  const _DescriptionCard({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      padding: EdgeInsets.all(isMobile ? 18 : 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 22,
            offset: const Offset(0, 14),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobile ? 22 : 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),

          // Paragraph only
          Text(
            description,
            style: GoogleFonts.lato(
              fontSize: isMobile ? 14.5 : 15.5,
              height: 1.65,
              color: Colors.black87.withOpacity(.85),
            ),
          ),

          const SizedBox(height: 22),

          // CTA (Optional)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Explore Collection",
                  style: GoogleFonts.lato(
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_ios, size: 14, color: kGold),
              ],
            ),
          ),
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
    final imageUrl =
        widget.product['imagePath'] ?? widget.product['image']?.toString();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 230,
        margin: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppDS.radiusMd,
          boxShadow: [
            AppDS.softShadow.copyWith(
              blurRadius: _isHovered ? 24 : 16,
              offset: Offset(0, _isHovered ? 14 : 10),
            ),
          ],
        ),
        transform: _isHovered
            ? (Matrix4.identity()..translate(0.0, -6.0))
            : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: imageUrl == null
                      ? const ColoredBox(
                          color: Color(0xFFF0E6DD),
                          child: Icon(Icons.category, size: 40),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.category, size: 40),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product['name']!.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kTextTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product['price']!.toString(),
                    style: kTextTheme.bodyLarge?.copyWith(
                      color: kGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kGold, width: 1.3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Add to Cart',
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kGold,
                        ),
                      ),
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

// --- Featured Collections / Stories ---

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
    final bool isMobileLocal = MediaQuery.of(context).size.width < 800;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
      child: Column(
        children: [
          Text(
            'BEST COLLECTIONS',
            style: AppDS.sectionLabel.copyWith(
              fontSize: isMobileLocal ? 13 : 14,
              letterSpacing: 2,
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white70
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Handpicked favourites from your store',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: isMobileLocal ? 22 : 26,
              fontWeight: FontWeight.w600,
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          if (!kIsWeb)
            ElevatedButton(
              onPressed: _selectFeaturedStories,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: kGold,
                elevation: 0,
                side: const BorderSide(color: kGold),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Select Best Collections'),
            ),
          const SizedBox(height: 32),
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
        int crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;
        double aspectRatio = 16 / 9;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
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
    final bool isMobileLocal = MediaQuery.of(context).size.width < 800;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.12 : 0.06),
              blurRadius: _isHovered ? 22 : 14,
              offset: Offset(0, _isHovered ? 16 : 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(18.0),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    widget.title,
                    style: GoogleFonts.lora(
                      fontSize: isMobileLocal ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Shop by Recipient ---

class ShopByRecipientSection extends StatefulWidget {
  final String? userId;
  final String? shopName;
  final String? logoUrl;

  const ShopByRecipientSection(
      {Key? key, this.userId, this.shopName, this.logoUrl})
      : super(key: key);

  @override
  _ShopByRecipientSectionState createState() => _ShopByRecipientSectionState();
}

class _ShopByRecipientSectionState extends State<ShopByRecipientSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      color: _websiteTheme == WebsiteTheme.dark ? Colors.black : AppDS.bgLight,
      child: Column(
        children: [
          Text(
            'SHOP BY RECIPIENT',
            style: AppDS.sectionLabel.copyWith(
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thoughtful pieces for every story',
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRecipientCard(context, 'Him', 'assets/gender/him.jpg'),
              const SizedBox(width: 14),
              _buildRecipientCard(context, 'Her', 'assets/gender/her.jpg'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientCard(
      BuildContext context, String title, String imageUrl) {
    final screenWidth = MediaQuery.of(context).size.width;

    // responsive capped size
    final double imageSize = screenWidth * 0.28; // 28% width chunk
    final double finalSize = imageSize > 150 ? 150 : imageSize; // cap at 150px

    return GestureDetector(
      onTap: () async {
        if (widget.userId == null) return;
        final products = await FirestoreService()
            .getProductsForGender(widget.userId!, title);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductsPage(
              userId: widget.userId!,
              categoryName: title,
              products: products,
              shopName: widget.shopName,
              logoUrl: widget.logoUrl,
              websiteTheme: _websiteTheme,
            ),
          ),
        );
      },
      child: Column(
        children: [
          SizedBox(
            width: finalSize,
            height: finalSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.lato(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Category Carousel ---

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
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1024;
    final bool isDesktop = width >= 1024;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_categories.isEmpty) {
      return const Center(child: Text('No categories found.'));
    }

    return Container(
      color: _websiteTheme == WebsiteTheme.dark
          ? Colors.black
          : Colors.transparent,
      padding: const EdgeInsets.only(top: 16.0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 12.0),
            child: Text(
              'SHOP BY CATEGORY',
              style: sectionHeadingStyle(context),
            ),
          ),
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: _categories.entries.map((entry) {
                  return SizedBox(
                    width: 120,
                    child: CategoryItem(
                      name: entry.key,
                      imageUrl: entry.value,
                      shopName: widget.shopName,
                      logoUrl: widget.logoUrl,
                      userId: widget.userId,
                    ),
                  );
                }).toList(),
              ),
            )
          else
            SizedBox(
              height: isMobile ? 130 : 155,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final categoryName = _categories.keys.elementAt(index);
                  final imageUrl = _categories[categoryName];
                  return CategoryItem(
                    name: categoryName,
                    imageUrl: imageUrl,
                    shopName: widget.shopName,
                    logoUrl: widget.logoUrl,
                    userId: widget.userId,
                  );
                },
              ),
            )
        ],
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
    final isDark = _websiteTheme == WebsiteTheme.dark;
    return GestureDetector(
      onTap: () async {
        if (widget.userId == null) {
          return;
        }
        final products = await _firestoreService.getProductsForCategoryfor(
            widget.userId!, widget.name);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => ProductsPage(
            userId: widget.userId!,
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
          width: isMobile ? 90 : 110,
          margin: const EdgeInsets.symmetric(horizontal: 6.0),
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
                    borderRadius: BorderRadius.circular(999),
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.category, size: 38),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Footer ---

class Footer extends StatefulWidget {
  final String? activeUserId;
  final String? shopName;
  final String? logoUrl;
  final WebsiteTheme websiteTheme;
  const Footer(
      {Key? key,
      this.activeUserId,
      this.shopName,
      this.logoUrl,
      this.websiteTheme = WebsiteTheme.light})
      : super(key: key);

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
    final isDarkFooter = widget.websiteTheme == WebsiteTheme.dark;

    return Container(
      color: isDarkFooter ? Colors.black : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 52),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!kIsWeb)
            ElevatedButton(
              onPressed: () async {
                final List<FooterColumnData> footerData =
                    _footerData.entries.map((entry) {
                  return FooterColumnData(title: entry.key, links: entry.value);
                }).toList();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditFooterScreen(
                      footerData: footerData,
                      userId: widget.activeUserId!,
                    ),
                  ),
                );
                _fetchFooterData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: isDarkFooter ? Colors.white : Colors.black,
                elevation: 0,
                side: BorderSide(
                  color: isDarkFooter ? Colors.white54 : Colors.black26,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Edit Footer'),
            ),
          const SizedBox(height: 24),
          isMobile ? _buildMobileFooter() : _buildDesktopFooter(),
          const SizedBox(height: 40),
          Divider(
              color: isDarkFooter
                  ? Colors.white10
                  : Colors.black.withOpacity(0.06)),
          const SizedBox(height: 20),
          _buildMiniBar(),
        ],
      ),
    );
  }

  Widget _buildDesktopFooter() {
    final isDarkFooter = widget.websiteTheme == WebsiteTheme.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            flex: 2,
            child: _FooterColumn(
                userId: widget.activeUserId!,
                title: 'About',
                links: _footerData['About'] ?? [],
                websiteTheme: widget.websiteTheme)),
        Expanded(
            flex: 2,
            child: _FooterColumn(
              userId: widget.activeUserId!,
              title: 'Shop',
              links: _footerData['Shop'] ?? [],
              websiteTheme: widget.websiteTheme,
              onLinkTap: (categoryName) async {
                if (widget.activeUserId == null) return;
                final products = await FirestoreService()
                    .getProductsForCategoryfor(
                        widget.activeUserId, categoryName);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ProductsPage(
                    userId: widget.activeUserId!,
                    categoryName: categoryName,
                    products: products,
                    shopName: widget.shopName,
                    logoUrl: widget.logoUrl,
                    websiteTheme: widget.websiteTheme,
                  ),
                ));
              },
            )),
        Expanded(
            flex: 2,
            child: _FooterColumn(
                userId: widget.activeUserId!,
                title: 'Customer Care',
                links: _footerData['Customer Care'] ?? [],
                websiteTheme: widget.websiteTheme)),
        Expanded(
            flex: 3, child: _ConnectColumn(websiteTheme: widget.websiteTheme)),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FooterColumn(
            userId: widget.activeUserId!,
            title: 'About',
            links: _footerData['About'] ?? [],
            websiteTheme: widget.websiteTheme),
        const SizedBox(height: 24),
        _FooterColumn(
            userId: widget.activeUserId!,
            title: 'Shop',
            links: _footerData['Shop'] ?? [],
            websiteTheme: widget.websiteTheme,
            onLinkTap: (categoryName) async {
              if (widget.activeUserId == null) return;
              final products = await FirestoreService()
                  .getProductsForCategoryfor(widget.activeUserId, categoryName);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ProductsPage(
                  userId: widget.activeUserId!,
                  categoryName: categoryName,
                  products: products,
                  shopName: widget.shopName,
                  logoUrl: widget.logoUrl,
                  websiteTheme: widget.websiteTheme,
                ),
              ));
            }),
        const SizedBox(height: 24),
        _FooterColumn(
            userId: widget.activeUserId!,
            title: 'Customer Care',
            links: _footerData['Customer Care'] ?? [],
            websiteTheme: widget.websiteTheme),
        const SizedBox(height: 24),
        _ConnectColumn(websiteTheme: widget.websiteTheme),
      ],
    );
  }

  Widget _buildMiniBar() {
    final isDarkFooter = widget.websiteTheme == WebsiteTheme.dark;
    final textStyle = kTextTheme.bodyMedium?.copyWith(
      color: isDarkFooter ? Colors.white70 : Colors.black54,
      fontSize: 12,
    );

    return LayoutBuilder(builder: (context, constraints) {
      final bool isMobileLocal = constraints.maxWidth < 600;
      if (isMobileLocal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('2024 Lustra. All Rights Reserved.', style: textStyle),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FooterLink(text: 'Privacy Policy'),
                SizedBox(width: 20),
                _FooterLink(text: 'Terms of Service'),
              ],
            ),
          ],
        );
      } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('2024 Lustra. All Rights Reserved.', style: textStyle),
            const SizedBox(width: 24),
            const Row(
              children: [
                _FooterLink(text: 'Privacy Policy'),
                SizedBox(width: 20),
                _FooterLink(text: 'Terms of Service'),
              ],
            ),
          ],
        );
      }
    });
  }
}

class _FooterColumn extends StatelessWidget {
  final String userId;
  final String title;
  final List<String> links;
  final Function(String)? onLinkTap;
  final WebsiteTheme websiteTheme;

  const _FooterColumn(
      {Key? key,
      required this.userId,
      required this.title,
      required this.links,
      this.onLinkTap,
      this.websiteTheme = WebsiteTheme.light})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkFooter = websiteTheme == WebsiteTheme.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(title,
            style: kTextTheme.headlineSmall?.copyWith(
                fontSize: 18,
                color: isDarkFooter ? Colors.white : Colors.black),
            maxLines: 1,
            minFontSize: 14),
        const SizedBox(height: 18),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _FooterLink(
                text: link,
                onTap: () {
                  if (link == 'Contact Us') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ContactUsScreen(userId: userId)));
                  } else if (onLinkTap != null) {
                    onLinkTap!(link);
                  }
                },
                websiteTheme: websiteTheme,
              ),
            )),
      ],
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final WebsiteTheme websiteTheme;
  const _FooterLink(
      {Key? key,
      required this.text,
      this.onTap,
      this.websiteTheme = WebsiteTheme.light})
      : super(key: key);

  @override
  __FooterLinkState createState() => __FooterLinkState();
}

class __FooterLinkState extends State<_FooterLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDarkFooter = widget.websiteTheme == WebsiteTheme.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Text(
            widget.text,
            style: kTextTheme.bodyLarge?.copyWith(
              fontSize: 13,
              color: isDarkFooter ? Colors.white70 : Colors.black87,
              decoration:
                  _isHovered ? TextDecoration.underline : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectColumn extends StatefulWidget {
  final WebsiteTheme websiteTheme;
  const _ConnectColumn({Key? key, this.websiteTheme = WebsiteTheme.light})
      : super(key: key);

  @override
  __ConnectColumnState createState() => __ConnectColumnState();
}

class __ConnectColumnState extends State<_ConnectColumn> {
  String? _shopAddress;
  String? _instaId;

  @override
  void initState() {
    super.initState();
    _fetchConnectDetails();
  }

  Future<void> _fetchConnectDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _shopAddress = data?['shopAddress'];
          _instaId = data?['instagramId'];
        });
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Widget _buildSocialIcon(IconData icon, VoidCallback? onPressed) {
    final isDarkFooter = widget.websiteTheme == WebsiteTheme.dark;
    final borderColor = isDarkFooter ? Colors.white70 : Colors.black54;
    final iconColor = isDarkFooter ? Colors.white : Colors.black;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.3),
        ),
        child: FaIcon(icon, size: 18, color: iconColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkFooter = widget.websiteTheme == WebsiteTheme.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect With Us',
            style: kTextTheme.headlineSmall?.copyWith(
                fontSize: 18,
                color: isDarkFooter ? Colors.white : Colors.black)),
        const SizedBox(height: 18),
        Row(
          children: [
            _buildSocialIcon(FontAwesomeIcons.facebookF, null),
            if (_instaId != null && _instaId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 14.0),
                child: _buildSocialIcon(FontAwesomeIcons.instagram, () {
                  _launchURL('https://instagram.com/$_instaId');
                }),
              ),
          ],
        ),
        if (_shopAddress != null && _shopAddress!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Text(
              _shopAddress!,
              style: kTextTheme.bodyLarge?.copyWith(
                color: isDarkFooter ? Colors.white70 : Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}
