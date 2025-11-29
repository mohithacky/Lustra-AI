import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
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
import 'package:lustra_ai/screens/cart_page.dart';
import 'package:lustra_ai/screens/orders_page.dart';
import 'package:lustra_ai/screens/add_collection_screen.dart';
import 'package:lustra_ai/screens/delete_collection_screen.dart';
import 'package:lustra_ai/screens/add_category_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lustra_ai/screens/edit_footer_screen.dart';
import 'package:lustra_ai/screens/contact_us_screen.dart';
import 'package:lustra_ai/screens/our_shop_screen.dart';
import 'package:lustra_ai/screens/footer_content_screen.dart';
import 'package:lustra_ai/models/footer_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lustra_ai/services/products_filters.dart';

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
  List<String> _productTypes = [];
  bool _isHoveringNav = false;
  bool _isHoveringMegaMenu = false;

  // Global website search UI state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchLoading = false;

  // 🔹 New: which mega menu is open on web ('collections', 'categories', 'Him', 'Her')
  String? _activeMegaMenuKey;

  String? _shopName;
  String? _logoUrl;
  String? _websiteUrl;
  String? _websiteType;
  User? _websiteCustomer;
  bool _isCustomerLoginLoading = false;
  bool _isDeploying = false;
  bool _isLoading = true;
  bool _showTestimonials = false;

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

    // Restore website customer session on web so login persists across refresh
    if (kIsWeb) {
      _websiteCustomer = FirebaseAuth.instance.currentUser;
    }

    if (widget.fromOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateAndUploadPosters();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      _websiteType = details?['websiteType'];

      final themeStr = details?['theme'];
      _websiteTheme =
          themeStr == 'dark' ? WebsiteTheme.dark : WebsiteTheme.light;

      final productTypes = (details?['productTypes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      _productTypes = productTypes;

      // Optional website testimonials section toggle
      _showTestimonials = (details?['showTestimonials'] as bool?) ?? false;

      _isLoading = false;
    });
  }

  Future<void> _handleWebsiteGoogleAuthTap() async {
    if (!kIsWeb) return;
    if (_websiteType != 'ecommerce') return;
    if (activeUserId == null) return;
    if (_isCustomerLoginLoading) return;

    if (_websiteCustomer == null) {
      await _signInWebsiteCustomer();
    } else {
      await _signOutWebsiteCustomer();
    }
  }

  Future<void> _signInWebsiteCustomer() async {
    if (!kIsWeb) return;
    final shopId = activeUserId;
    if (shopId == null) return;

    try {
      if (mounted) {
        setState(() {
          _isCustomerLoginLoading = true;
        });
      }

      final provider = GoogleAuthProvider();
      final credential = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = credential.user;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(shopId)
            .collection('users')
            .doc(user.uid)
            .set({
          'name': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          setState(() {
            _websiteCustomer = user;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCustomerLoginLoading = false;
        });
      }
    }
  }

  Future<void> _signOutWebsiteCustomer() async {
    if (!kIsWeb) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _websiteCustomer = null;
      });
    }
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
          websiteType: _websiteType,
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
    } else if (_productTypes.contains(value)) {
      if (activeUserId == null) return;
      final products =
          await ProductFilters.filterByProductType(activeUserId!, value);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ProductsPage(
          userId: activeUserId!,
          categoryName: value,
          products: products,
          shopName: _shopName,
          logoUrl: _logoUrl,
          websiteTheme: _websiteTheme,
          websiteType: _websiteType,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[CollectionsScreen] Building with shopName: $_shopName');
    isMobile = MediaQuery.of(context).size.width <= 600;
    final bool isEcommerceWeb =
        kIsWeb && _websiteType == 'ecommerce' && activeUserId != null;
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
        userId: activeUserId, // 🔹 Use activeUserId which has a fallback
        topNavItems: topNavItems,
        onNavSelected: _onNavItemSelected,
        collections: _collections, // 🔹 pass to drawer
        categories: _categoryNames, // 🔹 pass to drawer
        productTypes: _productTypes,
        showGoogleLogin: isEcommerceWeb,
        isCustomerLoggedIn: _websiteCustomer != null,
        onGoogleLoginTap: _handleWebsiteGoogleAuthTap,
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
    final bool isEcommerceWeb =
        kIsWeb && _websiteType == 'ecommerce' && activeUserId != null;

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
            ...[
              ...topNavItems,
              ..._productTypes.map((type) => {
                    "label": type,
                    "value": type,
                  })
            ].map((item) {
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
                    // 🔹 New: also trigger navigation on main button click
                    _onNavItemSelected(value);
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
          if (isEcommerceWeb)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: TextButton.icon(
                onPressed: _isCustomerLoginLoading
                    ? null
                    : _handleWebsiteGoogleAuthTap,
                icon: _isCustomerLoginLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _websiteCustomer == null ? Icons.login : Icons.logout,
                        color: isDarkMode ? Colors.white : AppDS.black,
                        size: 20,
                      ),
                label: Text(
                  _websiteCustomer == null ? 'Login' : 'Logout',
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : AppDS.black,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.favorite_border,
                size: 22, color: isDarkMode ? Colors.white : AppDS.black),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.shopping_cart_outlined,
                size: 22, color: isDarkMode ? Colors.white : AppDS.black),
            onPressed: isEcommerceWeb && _websiteCustomer != null
                ? () {
                    final shopId = activeUserId;
                    if (shopId == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CartPage(
                          shopId: shopId,
                          websiteCustomerId: _websiteCustomer!.uid,
                          shopName: _shopName,
                          logoUrl: _logoUrl,
                          websiteTheme: _websiteTheme,
                        ),
                      ),
                    );
                  }
                : null,
          ),
          if (isEcommerceWeb)
            IconButton(
              icon: Icon(Icons.receipt_long_outlined,
                  size: 22, color: isDarkMode ? Colors.white : AppDS.black),
              onPressed: _websiteCustomer != null
                  ? () {
                      final shopId = activeUserId;
                      if (shopId == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => OrdersPage(
                            shopId: shopId,
                            websiteCustomerId: _websiteCustomer!.uid,
                            shopName: _shopName,
                            logoUrl: _logoUrl,
                            websiteTheme: _websiteTheme,
                          ),
                        ),
                      );
                    }
                  : null,
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

    // Global search bar (visible on all website screens via Collections entry)
    slivers.add(
      SliverToBoxAdapter(
        child: _buildWebsiteSearchBar(isDarkMode),
      ),
    );

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

      if (_productTypes.length > 1)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ProductTypesSection(
                userId: activeUserId,
                shopName: _shopName,
                logoUrl: _logoUrl,
                productTypes: _productTypes,
              ),
            ),
          ),
        ),

      if (_productTypes.length > 1)
        const SliverToBoxAdapter(child: SizedBox(height: 40)),

      SliverToBoxAdapter(
        child: BlurrableSection(
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
      ),

      SliverToBoxAdapter(
        child: BlurrableSection(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ProductShowcase(
                  userId: activeUserId,
                  websiteType: _websiteType,
                  websiteCustomerId: _websiteCustomer?.uid),
            ),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 70),
      ),

      SliverToBoxAdapter(
        child: BlurrableSection(
          child: Center(
            child: FourBoxStaggeredSection(),
          ),
        ),
      ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 70),
      ),
      SliverToBoxAdapter(
        child: BlurrableSection(
          child: OverlappingBoxes(),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 40)),

      SliverToBoxAdapter(
        child: BlurrableSection(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: const ShopByOccasionBanner(),
            ),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),

      SliverToBoxAdapter(
        child: BlurrableSection(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: FeaturedCollectionsShowcase(userId: activeUserId),
            ),
          ),
        ),
      ),

      if (_showTestimonials)
        const SliverToBoxAdapter(
          child: SizedBox(height: 40),
        ),

      if (_showTestimonials)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16.0 : 120.0,
              vertical: 32.0,
            ),
            child: const JewelleryTestimonialSection(),
          ),
        ),

      SliverToBoxAdapter(
        child: Footer(
          activeUserId: activeUserId,
          shopName: _shopName,
          logoUrl: _logoUrl,
          websiteTheme: _websiteTheme,
          websiteType: _websiteType,
        ),
      ),
    ]);

    return slivers;
  }

  Widget _buildWebsiteSearchBar(bool isDarkMode) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.18)
                    : Colors.black.withOpacity(0.08),
              ),
              boxShadow: isDarkMode
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search,
                  size: 20,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Search for jewellery, categories, collections...',
                      hintStyle: GoogleFonts.lato(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white60 : Colors.black45,
                      ),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _onSearchSubmitted,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: _isSearchLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode ? kGold : AppDS.black,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: () =>
                              _onSearchSubmitted(_searchController.text),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'Search',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? kGold : AppDS.black,
                            ),
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

  Future<void> _onSearchSubmitted(String rawQuery) async {
    final shopId = activeUserId;
    if (shopId == null) return;

    final query = rawQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchLoading = true;
    });

    try {
      final results = await ProductFilters.searchProductsByText(shopId, query);
      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching products found.'),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProductsPage(
            userId: shopId,
            categoryName: 'Search: ' + query,
            products: results,
            shopName: _shopName,
            logoUrl: _logoUrl,
            websiteTheme: _websiteTheme,
            websiteType: _websiteType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Unable to search products right now. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearchLoading = false;
        });
      }
    }
  }

  // ───────────────────── Mega menu builders ─────────────────────

  Widget _buildActiveMegaMenu(bool isDarkMode) {
    final key = _activeMegaMenuKey;
    if (key == null) {
      return const SizedBox.shrink();
    }

    if (key == 'collections') {
      return _buildCollectionsMegaMenu(isDarkMode);
    }

    if (key == 'categories' ||
        key == 'Categories' ||
        key == 'Him' ||
        key == 'Her' ||
        _productTypes.contains(key)) {
      return _buildCategoriesMegaMenu(key, isDarkMode);
    }

    return const SizedBox.shrink();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collections',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _activeMegaMenuKey = null);
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
                    width: 240,
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
                        const SizedBox(height: 10),

                        /// Category Buttons
                        ..._categoryNames.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () async {
                                if (activeUserId == null) return;
                                final products = await ProductFilters
                                    .filterByCollectionCategory(context,
                                        collectionName, cat, activeUserId!);
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) => ProductsPage(
                                    userId: activeUserId!,
                                    categoryName: cat,
                                    products: products,
                                    shopName: _shopName,
                                    logoUrl: _logoUrl,
                                    websiteTheme: _websiteTheme,
                                  ),
                                ));
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.06)
                                      : Colors.grey.shade100,
                                ),
                                child: Text(
                                  cat,
                                  style: GoogleFonts.lato(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() => _activeMegaMenuKey = null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Buttons Layout
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: _categoryNames.map((cat) {
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    if (title == 'Categories' || title == 'categories') {
                      if (activeUserId == null) return;
                      final products = await ProductFilters.filterByCategory(
                          context, cat, activeUserId!);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ProductsPage(
                          userId: activeUserId!,
                          categoryName: cat,
                          products: products,
                          shopName: _shopName,
                          logoUrl: _logoUrl,
                          websiteTheme: _websiteTheme,
                        ),
                      ));
                    } else if (title == 'Him') {
                      final products = await ProductFilters.filterByHimCategory(
                          activeUserId, "Him", cat);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ProductsPage(
                          userId: activeUserId!,
                          categoryName: cat,
                          products: products,
                          shopName: _shopName,
                          logoUrl: _logoUrl,
                          websiteTheme: _websiteTheme,
                        ),
                      ));
                    } else if (title == 'Her') {
                      final products = await ProductFilters.filterByHerCategory(
                          activeUserId, "Her", cat);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ProductsPage(
                          userId: activeUserId!,
                          categoryName: cat,
                          products: products,
                          shopName: _shopName,
                          logoUrl: _logoUrl,
                          websiteTheme: _websiteTheme,
                        ),
                      ));
                    } else if (_productTypes.contains(title)) {
                      if (activeUserId == null) return;
                      final products =
                          await ProductFilters.filterByProductTypeAndCategory(
                              activeUserId!, title, cat);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => ProductsPage(
                          userId: activeUserId!,
                          categoryName: cat,
                          products: products,
                          shopName: _shopName,
                          logoUrl: _logoUrl,
                          websiteTheme: _websiteTheme,
                        ),
                      ));
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade100,
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
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

class ShopByOccasionBanner extends StatefulWidget {
  const ShopByOccasionBanner({super.key});

  @override
  State<ShopByOccasionBanner> createState() => _ShopByOccasionBannerState();
}

class _ShopByOccasionBannerState extends State<ShopByOccasionBanner> {
  final List<_OccasionItem> _items = [
    _OccasionItem(
      title: 'Anniversary',
      imageUrl:
          'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?q=80&w=400',
    ),
    _OccasionItem(
      title: 'Most Gifted',
      imageUrl:
          'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?q=80&w=400',
    ),
    _OccasionItem(
      title: 'Birthday',
      imageUrl:
          'https://images.unsplash.com/photo-1524253482453-3fed8d2fe12b?q=80&w=400',
    ),
  ];

  Future<void> _editOccasion(int index) async {
    final item = _items[index];
    final titleController = TextEditingController(text: item.title);
    final imageController = TextEditingController(text: item.imageUrl);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Occasion'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _items[index] = _OccasionItem(
                    title: titleController.text.trim().isEmpty
                        ? item.title
                        : titleController.text.trim(),
                    imageUrl: imageController.text.trim().isEmpty
                        ? item.imageUrl
                        : imageController.text.trim(),
                  );
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 160 : 16,
        vertical: 8,
      ),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppDS.gold,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Shop by Occasion',
                      style: AppDS.h2.copyWith(
                          color: AppDS.white,
                          fontStyle: GoogleFonts.cedarvilleCursive().fontStyle),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thoughtful gifts for every celebration.',
                      style: AppDS.bodyMuted.copyWith(color: Colors.white70),
                    ),
                    // const SizedBox(height: 12),
                    // SizedBox(
                    //   height: 32,
                    //   child: ElevatedButton(
                    //     onPressed: () {},
                    //     child: const Row(
                    //       mainAxisSize: MainAxisSize.min,
                    //       children: [
                    //         Text('Explore', style: TextStyle(fontSize: 12)),
                    //         SizedBox(width: 4),
                    //         Icon(
                    //           Icons.arrow_forward_ios,
                    //           size: 10,
                    //           color: Colors.white,
                    //         ),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _OccasionCard(
                        title: item.title,
                        imageUrl: item.imageUrl,
                        onEdit: () => _editOccasion(index),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: _items.length,
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

class _OccasionItem {
  final String title;
  final String imageUrl;

  const _OccasionItem({required this.title, required this.imageUrl});
}

class _OccasionCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onEdit;

  const _OccasionCard({
    required this.title,
    required this.imageUrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: kIsWeb ? null : onEdit,
      child: Stack(
        children: [
          Container(
            width: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            width: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.55),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppDS.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppDS.body.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppDS.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 8,
                    color: AppDS.black,
                  ),
                ],
              ),
            ),
          ),
          if (!kIsWeb)
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
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
                              websiteTheme: _websiteTheme,
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
        ),
      ],
    );
  }
}

class Review {
  final String customerName;
  final String date;
  final double rating;
  final String reviewText;
  final String customerImage;
  final String purchasedItemName;
  final String purchasedItemImage;

  const Review({
    required this.customerName,
    required this.date,
    required this.rating,
    required this.reviewText,
    required this.customerImage,
    required this.purchasedItemName,
    required this.purchasedItemImage,
  });
}

final List<Review> _mockReviews = [
  const Review(
    customerName: 'Aarohi Mehta',
    date: 'Jan 2024',
    rating: 4.8,
    reviewText:
        'The bridal set I purchased was absolutely stunning. The detailing and finish made my wedding look complete.',
    customerImage:
        'https://images.pexels.com/photos/3760853/pexels-photo-3760853.jpeg',
    purchasedItemName: 'Heritage Kundan Bridal Set',
    purchasedItemImage:
        'https://images.pexels.com/photos/1158438/pexels-photo-1158438.jpeg',
  ),
  const Review(
    customerName: 'Simran Kaur',
    date: 'Dec 2023',
    rating: 5.0,
    reviewText:
        'I wanted something modern yet timeless for my engagement. The ring exceeded my expectations.',
    customerImage:
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg',
    purchasedItemName: 'Solitaire Halo Engagement Ring',
    purchasedItemImage:
        'https://images.pexels.com/photos/1191531/pexels-photo-1191531.jpeg',
  ),
  const Review(
    customerName: 'Neha Sharma',
    date: 'Oct 2023',
    rating: 4.6,
    reviewText:
        'Beautiful craftsmanship and very comfortable to wear. I get compliments every time.',
    customerImage:
        'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg',
    purchasedItemName: 'Everyday Diamond Studs',
    purchasedItemImage:
        'https://images.pexels.com/photos/1191531/pexels-photo-1191531.jpeg',
  ),
];

class JewelleryTestimonialSection extends StatefulWidget {
  const JewelleryTestimonialSection({super.key});

  @override
  State<JewelleryTestimonialSection> createState() =>
      _JewelleryTestimonialSectionState();
}

class _JewelleryTestimonialSectionState
    extends State<JewelleryTestimonialSection> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Text(
                'Client Love',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFamily: 'Didot',
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 2,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(height: 16),
              Text(
                'Stories from those who shine with us',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _mockReviews.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final review = _mockReviews[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.2)).clamp(0.0, 1.0);
                  }
                  return Transform.scale(
                    scale: Curves.easeOut.transform(value),
                    child: child,
                  );
                },
                child: TestimonialCard(review: review),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_mockReviews.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentIndex == index ? 24 : 8,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? const Color(0xFFD4AF37)
                    : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class TestimonialCard extends StatelessWidget {
  final Review review;

  const TestimonialCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            right: 20,
            child: Text(
              '"',
              style: TextStyle(
                fontSize: 100,
                color: const Color(0xFFD4AF37).withOpacity(0.1),
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(review.customerImage),
                        backgroundColor: Colors.grey[200],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          review.date,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(5, (index) {
                    if (index < review.rating.floor()) {
                      return const Icon(
                        Icons.star,
                        color: Color(0xFFD4AF37),
                        size: 18,
                      );
                    } else if (index < review.rating) {
                      return const Icon(
                        Icons.star_half,
                        color: Color(0xFFD4AF37),
                        size: 18,
                      );
                    } else {
                      return Icon(
                        Icons.star_border,
                        color: Colors.grey[300],
                        size: 18,
                      );
                    }
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  review.reviewText,
                  style: const TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'Sans-serif',
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          review.purchasedItemImage,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) =>
                              const Icon(Icons.diamond, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Purchased',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              review.purchasedItemName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  final String? shopName;
  final String? userId;
  final List<Map<String, String>> topNavItems;
  final Function(String) onNavSelected;
  final Map<String, String> collections;
  final List<String> categories;
  final List<String> productTypes;
  final bool showGoogleLogin;
  final bool isCustomerLoggedIn;
  final VoidCallback? onGoogleLoginTap;
  final bool isEcommerceWeb;
  final String? websiteCustomerId;

  const AppDrawer({
    Key? key,
    this.shopName,
    this.userId,
    required this.topNavItems,
    required this.onNavSelected,
    this.collections = const {},
    this.categories = const [],
    this.productTypes = const [],
    this.showGoogleLogin = false,
    this.isCustomerLoggedIn = false,
    this.onGoogleLoginTap,
    this.isEcommerceWeb = false,
    this.websiteCustomerId,
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
                  if (showGoogleLogin && onGoogleLoginTap != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onGoogleLoginTap,
                        icon: Icon(
                          isCustomerLoggedIn ? Icons.logout : Icons.login,
                          size: 18,
                        ),
                        label: Text(
                          isCustomerLoggedIn
                              ? 'Logout customer'
                              : 'Login with Google',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kBlack,
                          elevation: 0,
                          side: const BorderSide(color: Colors.black12),
                        ),
                      ),
                    ),
                  const Divider(),
                ],
              ),
            ),
            _buildCollectionsDrawerMega(context),
            _buildCategoriesDrawerMega(context, 'Categories'),
            _buildCategoriesDrawerMega(context, 'Him'),
            _buildCategoriesDrawerMega(context, 'Her'),
            ...productTypes
                .map((type) => _buildCategoriesDrawerMega(context, type)),
            const Divider(),
            _buildDrawerItem('Home', Icons.home_outlined),
            if (isEcommerceWeb)
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined,
                    color: kBlack, size: 20),
                title: Text(
                  'Cart',
                  style: GoogleFonts.lato(fontSize: 15, color: kBlack),
                ),
                onTap: () {
                  if (userId == null || websiteCustomerId == null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please login on the website to see cart'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CartPage(
                        shopId: userId!,
                        websiteCustomerId: websiteCustomerId!,
                        shopName: shopName,
                        logoUrl: null,
                        websiteTheme: _websiteTheme,
                      ),
                    ),
                  );
                },
              ),
            if (isEcommerceWeb)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined,
                    color: kBlack, size: 20),
                title: Text(
                  'Orders',
                  style: GoogleFonts.lato(fontSize: 15, color: kBlack),
                ),
                onTap: () {
                  if (userId == null || websiteCustomerId == null) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Please login on the website to see orders'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => OrdersPage(
                        shopId: userId!,
                        websiteCustomerId: websiteCustomerId!,
                        shopName: shopName,
                        logoUrl: null,
                        websiteTheme: _websiteTheme,
                      ),
                    ),
                  );
                },
              ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ContactUsScreen(userId: userId),
                ),
              ),
              child: _buildDrawerItem('Contact Us', Icons.support_agent),
            ),
            GestureDetector(
              onTap: () {
                if (userId == null) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FooterContentScreen(
                      userId: userId!,
                      title: 'FAQs',
                      heading: 'Frequently Asked Questions',
                      fieldKey: 'footer_faqs',
                      hintText:
                          'List common customer questions and clear answers here.',
                    ),
                  ),
                );
              },
              child: _buildDrawerItem('FAQs', Icons.help_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsDrawerMega(BuildContext context) {
    if (collections.isEmpty && categories.isEmpty) {
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
                    child: TextButton(
                      onPressed: () async {
                        if (userId == null) return;
                        final products =
                            await ProductFilters.filterByCollectionCategory(
                                context, collectionName, cat, userId!);
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => ProductsPage(
                            userId: userId!,
                            categoryName: cat,
                            products: products,
                            shopName: shopName ?? 'My Store',
                            logoUrl: null,
                            websiteTheme: _websiteTheme,
                          ),
                        ));
                      },
                      child: Text(
                        cat,
                        style: GoogleFonts.lato(fontSize: 12, color: kBlack),
                      ),
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

  Widget _buildCategoriesDrawerMega(BuildContext context, String title) {
    if (categories.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.label_outline, color: kBlack, size: 20),
        title: Text(
          title,
          style: GoogleFonts.lato(fontSize: 15, color: kBlack),
        ),
        onTap: () {
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
          leading: TextButton(
            onPressed: () async {
              if (userId == null) return;
              switch (title) {
                case 'Categories':
                  final products = await ProductFilters.filterByCategory(
                      context, cat, userId!);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProductsPage(
                      userId: userId!,
                      categoryName: cat,
                      products: products,
                      shopName: shopName ?? 'My Store',
                      logoUrl: null,
                      websiteTheme: _websiteTheme,
                    ),
                  ));
                  break;
                case 'Him':
                  final products = await ProductFilters.filterByHimCategory(
                      userId, "Him", cat);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProductsPage(
                      userId: userId!,
                      categoryName: cat,
                      products: products,
                      shopName: shopName ?? 'My Store',
                      logoUrl: null,
                      websiteTheme: _websiteTheme,
                    ),
                  ));
                  break;
                case 'Her':
                  final products = await ProductFilters.filterByHerCategory(
                      userId, "Her", cat);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProductsPage(
                      userId: userId!,
                      categoryName: cat,
                      products: products,
                      shopName: shopName ?? 'My Store',
                      logoUrl: null,
                      websiteTheme: _websiteTheme,
                    ),
                  ));
                  break;
                default:
                  final products =
                      await ProductFilters.filterByProductTypeAndCategory(
                          userId!, title, cat);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProductsPage(
                      userId: userId!,
                      categoryName: cat,
                      products: products,
                      shopName: shopName ?? 'My Store',
                      logoUrl: null,
                      websiteTheme: _websiteTheme,
                    ),
                  ));
                  break;
              }
            },
            child: Text(
              cat,
              style: GoogleFonts.lato(fontSize: 14, color: kBlack),
            ),
          ),
          onTap: () {},
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
  final String? websiteType;
  final String? websiteCustomerId;

  const ProductShowcase({
    Key? key,
    required this.userId,
    this.websiteType,
    this.websiteCustomerId,
  }) : super(key: key);

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
    final bool isEcommerceWeb =
        kIsWeb && widget.websiteType == 'ecommerce' && widget.userId != null;

    // When no user is associated (e.g. preview mode), show static dummy data.
    if (widget.userId == null) {
      final dummy = _getDummyProducts();
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
              itemCount: dummy.length,
              itemBuilder: (context, index) {
                return ProductCard(
                  product: dummy[index],
                  shopId: null,
                  isEcommerceWeb: false,
                  websiteCustomerId: null,
                );
              },
            ),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId!)
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('[ProductShowcase] Stream error: ${snapshot.error}');
        }

        final docs = snapshot.data?.docs ?? [];
        final products = docs.isNotEmpty
            ? docs
                .map((doc) => doc.data())
                .toList()
                .cast<Map<String, dynamic>>()
            : _getDummyProducts();

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
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: products[index],
                    shopId: widget.userId!,
                    isEcommerceWeb: isEcommerceWeb,
                    websiteCustomerId: widget.websiteCustomerId,
                  );
                },
              ),
            ),
          ],
        );
      },
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

class BlurrableSection extends StatefulWidget {
  final Widget child;

  const BlurrableSection({super.key, required this.child});

  @override
  State<BlurrableSection> createState() => _BlurrableSectionState();
}

class _BlurrableSectionState extends State<BlurrableSection> {
  bool _isBlurred = false;

  void _toggleBlur() {
    setState(() {
      _isBlurred = !_isBlurred;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (_isBlurred) {
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: content,
      );
    }

    if (kIsWeb) {
      return content;
    }

    return Stack(
      children: [
        content,
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(
              Icons.info_outline,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _toggleBlur,
          ),
        ),
      ],
    );
  }
}

class FourBoxStaggeredSection extends StatefulWidget {
  const FourBoxStaggeredSection({super.key});

  @override
  State<FourBoxStaggeredSection> createState() =>
      _FourBoxStaggeredSectionState();
}

class _FourBoxStaggeredSectionState extends State<FourBoxStaggeredSection> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      {"label": "Wedding", "image": "https://picsum.photos/600?1"},
      {"label": "Diamond", "image": "https://picsum.photos/600?2"},
      {"label": "Bridal", "image": "https://picsum.photos/600?3"},
      {"label": "Elegant", "image": "https://picsum.photos/600?4"},
    ];
  }

  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < 600) return 16;
    if (width < 1200) return 32;
    return 150;
  }

  Future<void> _editItem(int index) async {
    final current = _items[index];
    final labelController = TextEditingController(text: current["label"] ?? "");
    final imageController = TextEditingController(text: current["image"] ?? "");

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit tile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'label': labelController.text.trim(),
                  'image': imageController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _items[index] = {
        'label': result['label']?.isNotEmpty == true
            ? result['label']!
            : (current['label'] ?? ''),
        'image': result['image']?.isNotEmpty == true
            ? result['image']!
            : (current['image'] ?? ''),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final hPadding = _getResponsivePadding(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          padding: EdgeInsets.symmetric(horizontal: hPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'TRENDING',
                style: sectionHeadingStyle(context),
              ),
              const SizedBox(height: 6),
              Text(
                'Discover what shoppers are loving right now',
                style: subheadingStyle(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              StaggeredGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 0.8,
                    child: GridBox(
                      item: _items[0],
                      onEdit: () => _editItem(0),
                    ),
                  ),
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 1.2,
                    child: GridBox(
                      item: _items[1],
                      onEdit: () => _editItem(1),
                    ),
                  ),
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 1.2,
                    child: GridBox(
                      item: _items[2],
                      onEdit: () => _editItem(2),
                    ),
                  ),
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 0.8,
                    child: GridBox(
                      item: _items[3],
                      onEdit: () => _editItem(3),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridBox extends StatelessWidget {
  final Map<String, String> item;
  final VoidCallback onEdit;

  const GridBox({
    super.key,
    required this.item,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              item["image"] ?? '',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
          if (!kIsWeb)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onEdit,
              ),
            ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Text(
              item["label"] ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OverlappingBoxes extends StatefulWidget {
  const OverlappingBoxes({super.key});

  @override
  State<OverlappingBoxes> createState() => _OverlappingBoxesState();
}

class _OverlappingBoxesState extends State<OverlappingBoxes> {
  String _imageUrl =
      'https://images.pexels.com/photos/415829/pexels-photo-415829.jpeg';
  String _text =
      'Season Sale is Live!\nUp to 50% OFF\nLimited-time jewellery offers.';

  Future<void> _editImage() async {
    final controller = TextEditingController(text: _imageUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit image URL'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Image URL'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      _imageUrl = result;
    });
  }

  Future<void> _editText() async {
    final controller = TextEditingController(text: _text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Sale & discount text',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      _text = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double sidePadding = 20;

    final usableWidth = screenWidth - (sidePadding * 2);

    double baseWidth;
    if (screenWidth < 380) {
      baseWidth = screenWidth * 0.50;
    } else if (screenWidth < 600) {
      baseWidth = screenWidth * 0.42;
    } else if (screenWidth < 1000) {
      baseWidth = screenWidth * 0.32;
    } else {
      baseWidth = screenWidth * 0.26;
    }

    double imgW = baseWidth;
    double imgH = baseWidth * 0.8;

    double textW = baseWidth * 1.06;
    double textH = textW * 0.8;

    double totalWidth = imgW + textW;
    if (totalWidth > usableWidth) {
      double scale = usableWidth / totalWidth;
      imgW *= scale;
      textW *= scale;
      imgH = imgW * 0.8;
      textH = textW * 0.8;
    }

    final double containerWidth = imgW + textW;
    final bool isMobile = screenWidth < 480;

    const double verticalOverlap = 12;
    const double horizontalOverlap = 14;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: sidePadding),
      child: Center(
        child: SizedBox(
          width: containerWidth,
          height: textH + 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _buildImageCard(width: imgW, height: imgH),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: Offset(
                    isMobile ? -10 : -horizontalOverlap,
                    isMobile ? verticalOverlap : 0,
                  ),
                  child: _buildTextCard(width: textW, height: textH),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(_imageUrl),
          fit: BoxFit.cover,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: !kIsWeb
          ? Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _editImage,
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildTextCard({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade300, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (!kIsWeb)
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(
                  Icons.edit,
                  color: Colors.black87,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _editText,
              ),
            ),
          Center(
            child: Text(
              _text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturedCollectionsShowcase extends StatefulWidget {
  final String? userId;

  const FeaturedCollectionsShowcase({super.key, this.userId});

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

  String _generateDescription(String title) {
    return 'Discover the $title collection - a curated selection of handcrafted pieces designed to blend everyday wearability with timeless elegance. Each design tells its own story, perfect for celebrating your most cherished moments.';
  }

  Future<void> _editFeaturedCollections() async {
    if (widget.userId == null) return;

    final collections =
        await FirestoreService().getCollections(userId: widget.userId);
    if (collections.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add collections first.')),
      );
      return;
    }

    final collectionNames = collections.keys.toList();

    if (!mounted) return;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _SelectStoriesDialog(collections: collectionNames),
    );

    if (!mounted || selected == null || selected.length != 2) return;

    final bestCollections = [
      {
        'name': selected[0],
        'image': collections[selected[0]]!,
        'description': _generateDescription(selected[0]),
      },
      {
        'name': selected[1],
        'image': collections[selected[1]]!,
        'description': _generateDescription(selected[1]),
      },
    ];

    await FirestoreService().saveBestCollections(bestCollections);

    setState(() {
      featured = bestCollections;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    final bool isMobile = MediaQuery.of(context).size.width < 800;
    final bool canEdit = !kIsWeb && widget.userId != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "FEATURED COLLECTIONS",
                style: sectionHeadingStyle(context),
              ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    color: kGold,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _editFeaturedCollections,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (featured.isEmpty)
            const SizedBox(
              height: 80,
              child: Center(
                child: Text('No featured collections added yet.'),
              ),
            )
          else
            Column(
              children: List.generate(featured.length, (index) {
                final item = featured[index];
                final image = item["image"]!;
                final title = item["name"]!;
                final description =
                    item['description'] ?? _generateDescription(title);
                final bool reverseRow = index % 2 == 1;

                final bigImageWidget = _BigImageCard(imageUrl: image);
                final descriptionCard = _DescriptionCard(
                  title: title,
                  description: description,
                  userId: widget.userId,
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
  final String? userId;

  const _DescriptionCard({
    required this.title,
    required this.description,
    this.userId,
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
            onPressed: () async {
              if (userId == null) return;
              try {
                final products = await FirestoreService()
                    .getProductsForCollection(userId, title);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductsPage(
                      userId: userId!,
                      categoryName: title,
                      products: products,
                      shopName: null,
                      logoUrl: null,
                      websiteTheme: _websiteTheme,
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to open collection: $e'),
                  ),
                );
              }
            },
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
  final String? shopId;
  final bool isEcommerceWeb;
  final String? websiteCustomerId;

  const ProductCard({
    Key? key,
    required this.product,
    this.shopId,
    this.isEcommerceWeb = false,
    this.websiteCustomerId,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;

  Future<void> _handleAddToCart({bool buyNow = false}) async {
    if (!kIsWeb || !widget.isEcommerceWeb) return;

    final shopId = widget.shopId;
    final customerId = widget.websiteCustomerId;
    if (shopId == null || customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to your cart')),
      );
      return;
    }

    try {
      final rawId = (widget.product['id'] ??
              widget.product['productId'] ??
              widget.product['name'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString();

      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(shopId)
          .collection('users')
          .doc(customerId)
          .collection('cart')
          .doc(rawId);

      await cartRef.set({
        'productId': rawId,
        'name': widget.product['name'],
        'price': widget.product['price'],
        'image': _getProductImageUrl(),
        'quantity': FieldValue.increment(1),
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            buyNow ? 'Added to cart. Opening cart...' : 'Added to cart',
          ),
        ),
      );

      if (buyNow) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CartPage(
              shopId: shopId,
              websiteCustomerId: customerId,
              shopName: null,
              logoUrl: null,
              websiteTheme: _websiteTheme,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String imageUrl = _getProductImageUrl();

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
                  child: imageUrl.isEmpty
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
                    widget.product['name']?.toString() ?? 'Product',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kTextTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.product['price']?.toString() ?? '',
                    style: kTextTheme.bodyLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.isEcommerceWeb && kIsWeb && widget.shopId != null)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => _handleAddToCart(),
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
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _handleAddToCart(buyNow: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGold,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Buy Now',
                              style: GoogleFonts.lato(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
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

  String _getProductImageUrl() {
    final dynamic primary = widget.product['imagePath'] ??
        widget.product['image'] ??
        widget.product['imageUrl'];

    if (primary is String && primary.isNotEmpty) {
      return primary;
    }

    final dynamic imagesField = widget.product['images'];
    if (imagesField is List && imagesField.isNotEmpty) {
      final first = imagesField.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
    }

    return '';
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

class ProductTypesSection extends StatelessWidget {
  final String? userId;
  final String? shopName;
  final String? logoUrl;
  final List<String> productTypes;

  const ProductTypesSection(
      {Key? key,
      this.userId,
      this.shopName,
      this.logoUrl,
      required this.productTypes})
      : super(key: key);

  String _imageForType(String type) {
    switch (type.toLowerCase()) {
      case 'gold':
        return 'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fgold.jpg?alt=media&token=e33c59dd-d969-4803-a96a-cdc46ccddafa';
      case 'silver':
        return 'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fsilver.jpg?alt=media&token=7b18b85e-684f-4895-9f0c-1034e9d34448';
      case 'diamond':
        return 'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fdiamond.jpg?alt=media&token=ba8e24d2-5a32-47ef-98c7-eef9d3d8f6e5';
      default:
        return 'https://firebasestorage.googleapis.com/v0/b/lustra-ai.firebasestorage.app/o/assets%2Fdefault_categories%2Fgold.jpg?alt=media&token=e33c59dd-d969-4803-a96a-cdc46ccddafa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final double boxSize = isDesktop ? 300 : 150;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16.0 : 24.0,
        vertical: isDesktop ? 16.0 : 24.0,
      ),
      color: _websiteTheme == WebsiteTheme.dark ? Colors.black : AppDS.bgLight,
      child: Column(
        children: [
          Text(
            'SHOP BY PRODUCT TYPE',
            style: AppDS.sectionLabel.copyWith(
              color: _websiteTheme == WebsiteTheme.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore pieces by what you sell most',
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
          if (isDesktop)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: productTypes.map((type) {
                  final imageUrl = _imageForType(type);
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: InkWell(
                      onTap: () async {
                        if (userId == null) return;
                        final products =
                            await ProductFilters.filterByProductType(
                          userId!,
                          type,
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductsPage(
                              userId: userId!,
                              categoryName: type,
                              products: products,
                              shopName: shopName,
                              logoUrl: logoUrl,
                              websiteTheme: _websiteTheme,
                            ),
                          ),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: boxSize,
                            height: boxSize,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Center(
                                  child: Icon(Icons.error_outline),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            type,
                            textAlign: TextAlign.center,
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
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: productTypes.map((type) {
                final imageUrl = _imageForType(type);
                return InkWell(
                  onTap: () async {
                    if (userId == null) return;
                    final products = await ProductFilters.filterByProductType(
                      userId!,
                      type,
                    );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProductsPage(
                          userId: userId!,
                          categoryName: type,
                          products: products,
                          shopName: shopName,
                          logoUrl: logoUrl,
                          websiteTheme: _websiteTheme,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: boxSize,
                        height: boxSize,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(Icons.error_outline),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type,
                        textAlign: TextAlign.center,
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
              }).toList(),
            ),
        ],
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
    final bool isDesktop = screenWidth >= 1024;

    final double imageSize = screenWidth * 0.28;
    final double maxSize = isDesktop ? 300 : 150;
    final double finalSize = imageSize > maxSize ? maxSize : imageSize;

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
                    width: 240,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isMobileLocal = screenWidth < 600;
    final double boxWidth = isDesktop ? 220 : (isMobileLocal ? 90 : 110);
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
          width: boxWidth,
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
  final String? websiteType;
  const Footer(
      {Key? key,
      this.activeUserId,
      this.shopName,
      this.logoUrl,
      this.websiteTheme = WebsiteTheme.light,
      this.websiteType})
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
            IconButton(
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
              icon: Icon(
                Icons.edit,
                color: isDarkFooter ? Colors.white : Colors.black,
              ),
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
                    websiteType: widget.websiteType,
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
                  websiteType: widget.websiteType,
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
        _ConnectColumn(
          websiteTheme: widget.websiteTheme,
          userId: widget.activeUserId,
        ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FooterLink(
                  text: 'Privacy Policy',
                  onTap: widget.activeUserId == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FooterContentScreen(
                                userId: widget.activeUserId!,
                                title: 'Privacy Policy',
                                heading: 'Privacy Policy',
                                fieldKey: 'footer_privacy_policy',
                                hintText:
                                    'Add your privacy policy details here for your customers to review.',
                              ),
                            ),
                          );
                        },
                  websiteTheme: widget.websiteTheme,
                ),
                const SizedBox(width: 20),
                _FooterLink(
                  text: 'Terms of Service',
                  onTap: widget.activeUserId == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FooterContentScreen(
                                userId: widget.activeUserId!,
                                title: 'Terms of Service',
                                heading: 'Terms of Service',
                                fieldKey: 'footer_terms_of_service',
                                hintText:
                                    'Outline your terms of service, usage conditions, and important legal information here.',
                              ),
                            ),
                          );
                        },
                  websiteTheme: widget.websiteTheme,
                ),
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
            Row(
              children: [
                _FooterLink(
                  text: 'Privacy Policy',
                  onTap: widget.activeUserId == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FooterContentScreen(
                                userId: widget.activeUserId!,
                                title: 'Privacy Policy',
                                heading: 'Privacy Policy',
                                fieldKey: 'footer_privacy_policy',
                                hintText:
                                    'Add your privacy policy details here for your customers to review.',
                              ),
                            ),
                          );
                        },
                  websiteTheme: widget.websiteTheme,
                ),
                const SizedBox(width: 20),
                _FooterLink(
                  text: 'Terms of Service',
                  onTap: widget.activeUserId == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FooterContentScreen(
                                userId: widget.activeUserId!,
                                title: 'Terms of Service',
                                heading: 'Terms of Service',
                                fieldKey: 'footer_terms_of_service',
                                hintText:
                                    'Outline your terms of service, usage conditions, and important legal information here.',
                              ),
                            ),
                          );
                        },
                  websiteTheme: widget.websiteTheme,
                ),
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
                  } else if (link == 'Our Shop') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => OurShopScreen(userId: userId)));
                  } else if (link == 'Our Story') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FooterContentScreen(
                              userId: userId,
                              title: 'Our Story',
                              heading: 'Our Story',
                              fieldKey: 'footer_our_story',
                              hintText:
                                  'Share the story, heritage, and inspiration behind your brand here.',
                            )));
                  } else if (link == 'Careers') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FooterContentScreen(
                              userId: userId,
                              title: 'Careers',
                              heading: 'Careers',
                              fieldKey: 'footer_careers',
                              hintText:
                                  'Describe your hiring philosophy, open roles, or how candidates can reach you.',
                            )));
                  } else if (link == 'Press') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FooterContentScreen(
                              userId: userId,
                              title: 'Press',
                              heading: 'Press & Media',
                              fieldKey: 'footer_press',
                              hintText:
                                  'Highlight press mentions, features, or media contact details here.',
                            )));
                  } else if (link == 'FAQs') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FooterContentScreen(
                              userId: userId,
                              title: 'FAQs',
                              heading: 'Frequently Asked Questions',
                              fieldKey: 'footer_faqs',
                              hintText:
                                  'List common customer questions and clear answers here.',
                            )));
                  } else if (link == 'Shipping & Returns') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FooterContentScreen(
                              userId: userId,
                              title: 'Shipping & Returns',
                              heading: 'Shipping & Returns',
                              fieldKey: 'footer_shipping_returns',
                              hintText:
                                  'Explain your shipping timelines, delivery options, and return/exchange policy here.',
                            )));
                  } else if (link == 'Warranty') {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FooterContentScreen(
                              userId: userId,
                              title: 'Warranty',
                              heading: 'Warranty',
                              fieldKey: 'footer_warranty',
                              hintText:
                                  'Describe your product warranty coverage, duration, and claim process here.',
                            )));
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
  final String? userId;

  const _ConnectColumn({
    Key? key,
    this.websiteTheme = WebsiteTheme.light,
    this.userId,
  }) : super(key: key);

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
    final userId = widget.userId;
    if (userId == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists && mounted) {
      final data = doc.data();
      setState(() {
        _shopAddress = data?['shopAddress'];
        _instaId = data?['instagramId'];
      });
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
