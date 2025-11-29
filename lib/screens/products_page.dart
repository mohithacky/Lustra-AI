import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lustra_ai/models/jewellery.dart';
import 'package:lustra_ai/providers/cart_provider.dart';
import 'package:lustra_ai/screens/products_page.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:lustra_ai/services/products_filters.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/screens/cart_page.dart';
import 'jewellery_catalogue_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';

// Import shared color constants
import 'package:lustra_ai/screens/theme_selection_screen.dart';

const Color kOffWhite = Color(0xFFF8F7F4);
const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);
const Color kCream = Color(0xFFF8EDD1);
late bool isDarkMode;

class ProductsPage extends StatefulWidget {
  final String userId;
  final String categoryName;
  final List<Map<String, dynamic>> products;
  final String? shopName;
  final String? logoUrl;
  final WebsiteTheme? websiteTheme;
  final String? websiteType;

  const ProductsPage({
    Key? key,
    required this.categoryName,
    required this.userId,
    required this.products,
    this.shopName,
    this.logoUrl,
    this.websiteTheme,
    this.websiteType,
  }) : super(key: key);

  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  late List<Map<String, dynamic>> _products;
  final FirestoreService _firestoreService = FirestoreService();
  String? sellerPhone;
  String? sellerWhatsapp;
  bool isContactLoading = true;
  Map<String, String> _collections = {};
  List<String> _categoryNames = [];
  late String _activeCategory;
  List<String> _subcategories = [];
  String _activeSubcategory = 'All';
  String? _websiteType;
  String? _websiteCustomerId;

  @override
  void initState() {
    super.initState();
    _products = widget.products;
    _activeCategory = widget.categoryName;
    _websiteType = widget.websiteType;
    isDarkMode = widget.websiteTheme == WebsiteTheme.dark;
    _fetchSellerContactDetails();
    _loadDrawerData();
    _loadWebsiteMeta();
    _loadSubcategoriesForActiveCategory();
  }

  Future<void> _fetchSellerContactDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      sellerPhone = doc.data()?['phoneNumber'];
      sellerWhatsapp = doc.data()?['whatsappNumber'] ?? sellerPhone;
    } catch (e) {
      debugPrint("Error fetching contact details: $e");
    }

    setState(() => isContactLoading = false);
  }

  Future<void> _loadDrawerData() async {
    try {
      final collections =
          await _firestoreService.getCollections(userId: widget.userId);
      final categoriesMap =
          await _firestoreService.getUserCategoriesFor(widget.userId);

      setState(() {
        _collections = collections;
        _categoryNames = categoriesMap.keys.map((e) => e.toString()).toList()
          ..sort();
      });
    } catch (e) {
      debugPrint('Error loading drawer data: $e');
    }
  }

  Future<void> _loadSubcategoriesForActiveCategory() async {
    if (_activeCategory == 'All') {
      setState(() {
        _subcategories = [];
        _activeSubcategory = 'All';
      });
      return;
    }

    try {
      // First try to load explicitly saved catalogue subcategories
      List<String> subs =
          await _firestoreService.getUserCatalogueSubcategoriesFor(
        widget.userId,
        _activeCategory,
      );

      // If none are saved, fall back to deriving subcategories
      // from the currently loaded products for this category.
      if (subs.isEmpty) {
        final derived = _products
            .where((p) => (p['category'] ?? '').toString() == _activeCategory)
            .map((p) => (p['subcategory'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        subs = derived;
      }

      if (!mounted) return;
      setState(() {
        _subcategories = subs;
        if (_subcategories.isEmpty) {
          _activeSubcategory = 'All';
        } else if (!_subcategories.contains(_activeSubcategory)) {
          _activeSubcategory = 'All';
        }
      });
    } catch (e) {
      debugPrint('Error loading subcategories: $e');
      if (!mounted) return;
      setState(() {
        _subcategories = [];
        _activeSubcategory = 'All';
      });
    }
  }

  Future<void> _loadWebsiteMeta() async {
    try {
      // Determine website type for this shop
      final details = await _firestoreService.getUserDetailsFor(widget.userId);
      final type = details?['websiteType'];
      final customerId = kIsWeb ? FirebaseAuth.instance.currentUser?.uid : null;

      if (mounted) {
        setState(() {
          _websiteType = type;
          _websiteCustomerId = customerId;
        });
      }
    } catch (e) {
      debugPrint('Error loading website meta: $e');
    }
  }

  Future<void> _refetchProducts() async {
    List<Map<String, dynamic>> updatedProducts;
    if (_activeCategory == 'All') {
      // When the global "All" category is selected, show all products
      updatedProducts =
          await _firestoreService.getAllProductsForUser(widget.userId);
    } else if (_activeSubcategory == 'All') {
      updatedProducts = await _firestoreService.getProductsForCategoryfor(
          widget.userId, _activeCategory);
    } else {
      updatedProducts =
          await _firestoreService.getProductsForCategoryAndSubcategoryFor(
        widget.userId,
        _activeCategory,
        _activeSubcategory,
      );
    }
    setState(() {
      _products = updatedProducts;
    });
  }

  Future<void> _onSubcategorySelected(String subcategory) async {
    if (_activeCategory == 'All') {
      return;
    }

    setState(() {
      _activeSubcategory = subcategory;
      _selectedFilter = 'All';
    });

    List<Map<String, dynamic>> updatedProducts;
    if (subcategory == 'All') {
      updatedProducts = await _firestoreService.getProductsForCategoryfor(
          widget.userId, _activeCategory);
    } else {
      updatedProducts =
          await _firestoreService.getProductsForCategoryAndSubcategoryFor(
        widget.userId,
        _activeCategory,
        _activeSubcategory,
      );
    }

    setState(() {
      _products = updatedProducts;
    });
  }

  Future<void> _applyFilter(String filter) async {
    setState(() {
      _selectedFilter = filter;
    });

    List<Map<String, dynamic>> updatedProducts;
    if (_activeCategory == 'All') {
      // When the global "All" category is selected, always show all products
      // for this shop, regardless of the smaller filter chips.
      updatedProducts =
          await _firestoreService.getAllProductsForUser(widget.userId);
    } else if (filter == 'All') {
      if (_activeSubcategory == 'All') {
        updatedProducts = await _firestoreService.getProductsForCategoryfor(
            widget.userId, _activeCategory);
      } else {
        updatedProducts =
            await _firestoreService.getProductsForCategoryAndSubcategoryFor(
          widget.userId,
          _activeCategory,
          _activeSubcategory,
        );
      }
    } else {
      if (_activeSubcategory == 'All') {
        updatedProducts =
            await _firestoreService.getProductsForCategoryforWithFilter(
          widget.userId,
          _activeCategory,
          filter,
        );
      } else {
        updatedProducts = await _firestoreService
            .getProductsForCategoryAndSubcategoryForWithFilter(
          widget.userId,
          _activeCategory,
          _activeSubcategory,
          filter,
        );
      }
    }

    setState(() {
      _products = updatedProducts;
    });
  }

  Future<void> _onCategorySelected(String category) async {
    setState(() {
      _activeCategory = category;
      _selectedFilter = 'All';
      _activeSubcategory = 'All';
    });

    List<Map<String, dynamic>> updatedProducts;
    if (category == 'All') {
      // When the global "All" category is selected, always show all products
      // for this shop, regardless of the smaller filter chips.
      updatedProducts =
          await _firestoreService.getAllProductsForUser(widget.userId);
    } else {
      updatedProducts = await _firestoreService.getProductsForCategoryfor(
          widget.userId, _activeCategory);
    }

    setState(() {
      _products = updatedProducts;
    });

    // Now that products for the new category are loaded, refresh subcategories.
    await _loadSubcategoriesForActiveCategory();
  }

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'New Arrivals',
    'Bestsellers',
    'Trending',
    'Sale'
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 600;
    const bool isAdminApp = !kIsWeb;
    final bool isEcommerceWeb =
        kIsWeb && _websiteType == 'ecommerce' && widget.userId.isNotEmpty;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      drawer: _buildMobileDrawer(),
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: isDarkMode ? Colors.white : kBlack,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(widget.logoUrl!),
                  radius: 16,
                ),
              ),
            Flexible(
              child: AutoSizeText(
                widget.shopName ?? 'YOUR BRAND',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDarkMode ? Colors.white : kBlack,
                ),
                maxLines: 1,
                minFontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              size: 22,
              color: isDarkMode ? Colors.white : kBlack,
            ),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(
              Icons.shopping_bag_outlined,
              size: 22,
              color: isDarkMode ? Colors.white : kBlack,
            ),
            onPressed: isEcommerceWeb && _websiteCustomerId != null
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CartPage(
                          shopId: widget.userId,
                          websiteCustomerId: _websiteCustomerId!,
                          shopName: widget.shopName,
                          logoUrl: widget.logoUrl,
                          websiteTheme: widget.websiteTheme,
                        ),
                      ),
                    );
                  }
                : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _activeCategory,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : kBlack,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdminApp)
                          IconButton(
                            tooltip: 'Add Product',
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: kGold,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const JewelleryCatalogueScreen(),
                                ),
                              );
                              _refetchProducts();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 8,
                        children: _filterOptions
                            .map((filter) => _buildFilterChip(filter))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildCategoryFilterChip('All'),
                          ),
                          ..._categoryNames.map(
                            (category) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildCategoryFilterChip(category),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _activeCategory == 'All' || _subcategories.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Wrap(
                              spacing: 8,
                              children: [
                                _buildSubcategoryFilterChip('All'),
                                ..._subcategories
                                    .map((sub) =>
                                        _buildSubcategoryFilterChip(sub))
                                    .toList(),
                              ],
                            ),
                          ),
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: isMobile ? 2 : 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childCount: _products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(
                        product: _products[index],
                        sellerPhone: sellerPhone,
                        sellerWhatsapp: sellerWhatsapp,
                        isContactLoading: isContactLoading,
                        shopId: widget.userId,
                        shopName: widget.shopName,
                        logoUrl: widget.logoUrl,
                        websiteTheme: widget.websiteTheme,
                        isEcommerceWeb: isEcommerceWeb,
                        websiteCustomerId: _websiteCustomerId,
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final bool isSelected = _selectedFilter == filter;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: kOffWhite,
      selectedColor: kGold.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? kGold : kBlack.withOpacity(0.3),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      label: Text(filter),
      labelStyle: TextStyle(
        color: isSelected ? kGold : kBlack.withOpacity(0.7),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (bool selected) {
        if (selected) {
          _applyFilter(filter);
        }
      },
    );
  }

  Widget _buildCategoryFilterChip(String category) {
    final bool isSelected = _activeCategory == category;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: kOffWhite,
      selectedColor: kGold.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? kGold : kBlack.withOpacity(0.3),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      label: Text(
        category,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? kGold : kBlack.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          _onCategorySelected(category);
        }
      },
    );
  }

  Widget _buildSubcategoryFilterChip(String subcategory) {
    final bool isSelected = _activeSubcategory == subcategory;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: kOffWhite,
      selectedColor: kGold.withOpacity(0.3),
      side: BorderSide(
        color: isSelected ? kGold : kBlack.withOpacity(0.3),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      label: Text(
        subcategory,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? kGold : kBlack.withOpacity(0.7),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onSelected: (bool selected) {
        if (selected) {
          _onSubcategorySelected(subcategory);
        }
      },
    );
  }

  // Desktop navbar
  PreferredSize _buildDesktopNavBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Row(
          children: [
            Flexible(
              flex: 2,
              child: _buildSearchField(),
            ),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _navMenuItem('Home'),
                  _navMenuItem('Collections'),
                  _navMenuItem('Earrings'),
                  _navMenuItem('Necklaces'),
                  _navMenuItem('Rings'),
                  const SizedBox(width: 20),
                  _iconButton(Icons.person_outline_rounded),
                  _iconButton(Icons.shopping_bag_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
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
                    widget.shopName != null && widget.shopName!.isNotEmpty
                        ? widget.shopName!
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
            ListTile(
              leading: const Icon(Icons.home_outlined, color: kBlack, size: 20),
              title: Text(
                'Home',
                style: GoogleFonts.lato(fontSize: 15, color: kBlack),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
            _buildCollectionsDrawerSection(),
            _buildCategoriesDrawerSection('Categories'),
            _buildCategoriesDrawerSection('Him'),
            _buildCategoriesDrawerSection('Her'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined,
                  color: kBlack, size: 20),
              title: Text(
                'My Orders',
                style: GoogleFonts.lato(fontSize: 15, color: kBlack),
              ),
              onTap: () {},
            ),
            ListTile(
              leading:
                  const Icon(Icons.favorite_border, color: kBlack, size: 20),
              title: Text(
                'Wishlist',
                style: GoogleFonts.lato(fontSize: 15, color: kBlack),
              ),
              onTap: () {},
            ),
            ListTile(
              leading:
                  const Icon(Icons.person_outline, color: kBlack, size: 20),
              title: Text(
                'My Account',
                style: GoogleFonts.lato(fontSize: 15, color: kBlack),
              ),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined,
                  color: kBlack, size: 20),
              title: Text(
                'Cart',
                style: GoogleFonts.lato(fontSize: 15, color: kBlack),
              ),
              onTap: () {
                final bool isEcommerceWeb =
                    kIsWeb && _websiteType == 'ecommerce';
                if (!isEcommerceWeb || _websiteCustomerId == null) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please login on the website to see cart'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => CartPage(
                      shopId: widget.userId,
                      websiteCustomerId: _websiteCustomerId!,
                      shopName: widget.shopName,
                      logoUrl: widget.logoUrl,
                      websiteTheme: widget.websiteTheme,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionsDrawerSection() {
    if (_collections.isEmpty && _categoryNames.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.grid_view, color: kBlack, size: 20),
        title: Text(
          'Collections',
          style: GoogleFonts.lato(fontSize: 15, color: kBlack),
        ),
        onTap: () {
          Navigator.of(context).pop();
        },
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.grid_view, color: kBlack, size: 20),
      title: Text(
        'Collections',
        style: GoogleFonts.lato(fontSize: 15, color: kBlack),
      ),
      children: _collections.keys.map((collectionName) {
        return Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 12.0, right: 16.0),
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
                children: _categoryNames.map((cat) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: TextButton(
                      onPressed: () async {
                        final products =
                            await ProductFilters.filterByCollectionCategory(
                          context,
                          collectionName,
                          cat,
                          widget.userId,
                        );
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProductsPage(
                              userId: widget.userId,
                              categoryName: cat,
                              products: products,
                              shopName: widget.shopName,
                              logoUrl: widget.logoUrl,
                              websiteTheme: widget.websiteTheme,
                            ),
                          ),
                        );
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

  Widget _buildCategoriesDrawerSection(String title) {
    if (_categoryNames.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.label_outline, color: kBlack, size: 20),
        title: Text(
          title,
          style: GoogleFonts.lato(fontSize: 15, color: kBlack),
        ),
        onTap: () {
          Navigator.of(context).pop();
        },
      );
    }

    return ExpansionTile(
      leading: const Icon(Icons.label_outline, color: kBlack, size: 20),
      title: Text(
        title,
        style: GoogleFonts.lato(fontSize: 15, color: kBlack),
      ),
      children: _categoryNames.map((cat) {
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 56, right: 16),
          leading: TextButton(
            onPressed: () async {
              List<Map<String, dynamic>> products;
              switch (title) {
                case 'Categories':
                  products = await ProductFilters.filterByCategory(
                    context,
                    cat,
                    widget.userId,
                  );
                  break;
                case 'Him':
                  products = await ProductFilters.filterByHimCategory(
                    widget.userId,
                    'Him',
                    cat,
                  );
                  break;
                case 'Her':
                  products = await ProductFilters.filterByHerCategory(
                    widget.userId,
                    'Her',
                    cat,
                  );
                  break;
                default:
                  return;
              }
              if (!mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProductsPage(
                    userId: widget.userId,
                    categoryName: cat,
                    products: products,
                    shopName: widget.shopName,
                    logoUrl: widget.logoUrl,
                    websiteTheme: widget.websiteTheme,
                  ),
                ),
              );
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

  Widget _buildSearchField() {
    return SizedBox(
      width: 300,
      height: 40,
      child: TextField(
        style: GoogleFonts.lato(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search for gold, diamonds...',
          hintStyle: GoogleFonts.lato(
            fontSize: 14,
            color: kBlack.withOpacity(0.5),
          ),
          prefixIcon: const Icon(Icons.search, color: kBlack, size: 20),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          filled: true,
          fillColor: kBlack.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _navMenuItem(String title) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        foregroundColor: kBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ).copyWith(
        overlayColor: WidgetStateProperty.all(kGold.withOpacity(0.1)),
      ),
      child: Text(
        title,
        style: GoogleFonts.lato(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, color: kBlack, size: 28),
      splashRadius: 24,
      tooltip: icon == Icons.person_outline_rounded ? 'Profile' : 'Cart',
    );
  }

  Widget _buildDrawerItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.lora(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: kBlack,
        ),
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final String shopId;
  final String? shopName;
  final String? logoUrl;
  final String? sellerPhone;
  final String? sellerWhatsapp;
  final bool isContactLoading;
  final bool isEcommerceWeb;
  final String? websiteCustomerId;
  final WebsiteTheme? websiteTheme;

  const ProductCard({
    Key? key,
    required this.product,
    required this.shopId,
    this.shopName,
    this.logoUrl,
    this.sellerPhone,
    this.sellerWhatsapp,
    this.isContactLoading = false,
    this.isEcommerceWeb = false,
    this.websiteCustomerId,
    this.websiteTheme,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isWishlisted = false;

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: widget.product,
          shopId: widget.shopId,
          shopName: widget.shopName,
          logoUrl: widget.logoUrl,
          isEcommerceWeb: widget.isEcommerceWeb,
          websiteCustomerId: widget.websiteCustomerId,
          websiteTheme: widget.websiteTheme,
          sellerPhone: widget.sellerPhone,
          sellerWhatsapp: widget.sellerWhatsapp,
          isContactLoading: widget.isContactLoading,
        ),
      ),
    );
  }

  Future<void> _handleAddToCart({bool buyNow = false}) async {
    if (!kIsWeb || !widget.isEcommerceWeb) {
      return;
    }

    final customerId = widget.websiteCustomerId;
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to your cart')),
      );
      return;
    }

    try {
      final shopId = widget.shopId;
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
              websiteTheme: null,
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
    final bool isMobile = MediaQuery.of(context).size.width <= 600;
    final double imageHeight = isMobile ? 180 : 240;
    final bool hasDiscount = widget.product.containsKey('originalPrice');
    final bool isBestseller = widget.product['isBestseller'] ?? false;
    final bool isTrending = widget.product['isTrending'] ?? false;

    return InkWell(
        onTap: _openDetails,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF111111) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: kBlack.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image + icons
              Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      _getProductImageUrl(),
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: double.infinity,
                        height: imageHeight,
                        color: kOffWhite,
                        alignment: Alignment.center,
                        child:
                            const Icon(Icons.image_not_supported, color: kGold),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isWishlisted = !_isWishlisted;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isWishlisted
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: _isWishlisted ? Colors.red : kBlack,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  if (isBestseller || isTrending)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kGold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isBestseller ? 'Bestseller' : 'Trending',
                          style: GoogleFonts.lato(
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Details
              Container(
                decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF1E1E1E)
                        : kGold.withOpacity(0.85),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16))),
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      widget.product['name'],
                      style: GoogleFonts.playfairDisplay(
                        fontSize: isMobile ? 14 : 18,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : kBlack,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(
                          '₹${widget.product['price'].toString()}',
                          style: GoogleFonts.lato(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : kBlack,
                          ),
                        ),
                        if (widget.product.containsKey('weight'))
                          Text(
                            (() {
                              final weightValue =
                                  widget.product['weight']?.toString() ?? '';
                              return weightValue.isNotEmpty
                                  ? '${weightValue}g'
                                  : '';
                            })(),
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.black.withOpacity(0.7),
                            ),
                          ),
                        if (hasDiscount)
                          Text(
                            '₹${widget.product['originalPrice'].toString()}',
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.w400,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.8)
                                  : Colors.black.withOpacity(0.7),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                    if (widget.product.containsKey('discount'))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: kCream,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Icon(Icons.discount_outlined,
                                  size: isMobile ? 12 : 14, color: kGold),
                              Text(
                                widget.product['discount'].toString(),
                                style: GoogleFonts.lato(
                                  fontSize: isMobile ? 10 : 12,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.9)
                                      : kBlack.withOpacity(0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (widget.isEcommerceWeb && kIsWeb)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _handleAddToCart(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                'Add to Cart',
                                style: GoogleFonts.lato(
                                  fontSize: isMobile ? 11 : 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _handleAddToCart(buyNow: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: kBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                              child: Text(
                                'Buy Now',
                                style: GoogleFonts.lato(
                                  fontSize: isMobile ? 11 : 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (widget.isContactLoading) return;

                                if (widget.sellerPhone == null ||
                                    widget.sellerPhone!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Phone number not available")),
                                  );
                                  return;
                                }

                                String phone = widget.sellerPhone!.trim();
                                if (!phone.startsWith('+')) phone = '+91$phone';

                                final Uri telUri = Uri.parse("tel:$phone");
                                await launchUrl(telUri,
                                    mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.call,
                                  size: 18, color: Colors.white),
                              label: Text(
                                "Call Now",
                                style: GoogleFonts.lato(
                                  fontSize: isMobile ? 11 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kBlack,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                if (widget.isContactLoading) return;

                                if (widget.sellerWhatsapp == null ||
                                    widget.sellerWhatsapp!.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("WhatsApp not available")),
                                  );
                                  return;
                                }

                                String phone = widget.sellerWhatsapp!.trim();
                                if (!phone.startsWith('+')) phone = '+91$phone';

                                final message = Uri.encodeComponent(
                                    "Hello, I'm interested in ${widget.product['name']}");
                                final Uri waUri = Uri.parse(
                                    "https://wa.me/$phone?text=$message");
                                await launchUrl(waUri,
                                    mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(FontAwesomeIcons.whatsapp,
                                  size: 18, color: Colors.white),
                              label: Text(
                                "WhatsApp",
                                style: GoogleFonts.lato(
                                  fontSize: isMobile ? 11 : 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  String _getProductImageUrl() {
    // Prefer explicit imagePath / image fields used by older products
    final dynamic primary = widget.product['imagePath'] ??
        widget.product['image'] ??
        widget.product['imageUrl'];

    if (primary is String && primary.isNotEmpty) {
      return primary;
    }

    // Fall back to first entry in `images` list if present
    final dynamic imagesField = widget.product['images'];
    if (imagesField is List && imagesField.isNotEmpty) {
      final first = imagesField.first;
      if (first is String && first.isNotEmpty) {
        return first;
      }
    }

    // As a last resort, return an empty string. The errorBuilder above
    // will render a graceful placeholder when the URL is invalid.
    return '';
  }
}

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;
  final String shopId;
  final String? shopName;
  final String? logoUrl;
  final bool isEcommerceWeb;
  final String? websiteCustomerId;
  final WebsiteTheme? websiteTheme;
  final String? sellerPhone;
  final String? sellerWhatsapp;
  final bool isContactLoading;

  const ProductDetailPage({
    super.key,
    required this.product,
    required this.shopId,
    this.shopName,
    this.logoUrl,
    this.isEcommerceWeb = false,
    this.websiteCustomerId,
    this.websiteTheme,
    this.sellerPhone,
    this.sellerWhatsapp,
    this.isContactLoading = false,
  });

  List<String> _getAllImageUrls() {
    final List<String> urls = [];
    final dynamic primary =
        product['imagePath'] ?? product['image'] ?? product['imageUrl'];
    if (primary is String && primary.isNotEmpty) {
      urls.add(primary);
    }
    final dynamic imagesField = product['images'];
    if (imagesField is List) {
      for (final item in imagesField) {
        if (item is String && item.isNotEmpty && !urls.contains(item)) {
          urls.add(item);
        }
      }
    }
    if (urls.isEmpty) {
      urls.add('');
    }
    return urls;
  }

  Future<void> _handleAddToCart(BuildContext context,
      {bool buyNow = false}) async {
    if (!kIsWeb || !isEcommerceWeb) {
      return;
    }

    final customerId = websiteCustomerId;
    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to your cart')),
      );
      return;
    }

    try {
      final rawId = (product['id'] ??
              product['productId'] ??
              product['name'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString();

      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(shopId)
          .collection('users')
          .doc(customerId)
          .collection('cart')
          .doc(rawId);

      // Reuse the same image selection logic as ProductCard.
      String image = '';
      final dynamic primary =
          product['imagePath'] ?? product['image'] ?? product['imageUrl'];
      if (primary is String && primary.isNotEmpty) {
        image = primary;
      } else {
        final dynamic imagesField = product['images'];
        if (imagesField is List && imagesField.isNotEmpty) {
          final first = imagesField.first;
          if (first is String && first.isNotEmpty) {
            image = first;
          }
        }
      }

      await cartRef.set({
        'productId': rawId,
        'name': product['name'],
        'price': product['price'],
        'image': image,
        'quantity': FieldValue.increment(1),
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
              websiteTheme: null,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to add to cart: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode;
    final bool isMobile = MediaQuery.of(context).size.width <= 600;
    final images = _getAllImageUrls();
    final name = (product['name'] ?? '').toString();
    final price = product['price'];
    final originalPrice = product['originalPrice'];
    final discount = product['discount'];
    final weight = product['weight'];
    final category = product['category'];
    final subcategory = product['subcategory'];
    final collection = product['collection'];
    final karat = product['karat'];
    final material = product['material'];
    final length = product['length'];
    final makingCharges = product['making_charges'];
    final stone = product['stone'];
    final sku = product['sku'];
    final description = product['description'];
    final stock = (product['stock'] ?? '').toString();
    final bool isBestseller = product['isBestseller'] ?? false;
    final bool isTrending = product['isTrending'] ?? false;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: dark ? Colors.white : kBlack),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (logoUrl != null && logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(logoUrl!),
                  radius: 16,
                ),
              ),
            Flexible(
              child: AutoSizeText(
                shopName ?? 'YOUR BRAND',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: dark ? Colors.white : kBlack,
                ),
                maxLines: 1,
                minFontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Media slider (images only) similar to catalogue detail.
                if (images.isNotEmpty && images.first.isNotEmpty)
                  SizedBox(
                    height: isMobile ? 260 : 320,
                    child: PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final url = images[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            url,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: dark ? Colors.black : kOffWhite,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: kGold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: isMobile ? 220 : 260,
                    decoration: BoxDecoration(
                      color: dark ? Colors.black : kOffWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dark ? kGold : kBlack.withOpacity(0.1),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.photo,
                      color: dark ? Colors.white24 : Colors.black26,
                      size: 40,
                    ),
                  ),
                const SizedBox(height: 16),
                // Name and optional badges / price
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : kBlack,
                  ),
                ),
                const SizedBox(height: 4),
                if (stock.isNotEmpty)
                  Text(
                    stock,
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: dark ? kGold : kBlack.withOpacity(0.75),
                    ),
                  ),
                const SizedBox(height: 8),
                if (isBestseller || isTrending)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isBestseller ? 'Bestseller' : 'Trending',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (isBestseller || isTrending) const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (price != null)
                      Text(
                        '₹${price.toString()}',
                        style: GoogleFonts.lato(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : kBlack,
                        ),
                      ),
                    if (originalPrice != null)
                      Text(
                        '₹${originalPrice.toString()}',
                        style: GoogleFonts.lato(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w400,
                          color: dark
                              ? Colors.white.withOpacity(0.8)
                              : Colors.black.withOpacity(0.7),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    if (discount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: kCream,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.discount_outlined,
                              size: 14,
                              color: kGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              discount.toString(),
                              style: GoogleFonts.lato(
                                fontSize: 12,
                                color: dark
                                    ? Colors.white.withOpacity(0.9)
                                    : kBlack.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Spec rows, similar to catalogue detail (only for fields present).
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Category',
                  value: category,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Subcategory',
                  value: subcategory,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Karat',
                  value: karat,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Material',
                  value: material,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Weight',
                  value: weight,
                  postfix: ' g',
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Length',
                  value: length,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Making charges',
                  value: makingCharges,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Stone',
                  value: stone,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'SKU',
                  value: sku,
                ),
                _buildDetailSpecRow(
                  context,
                  dark: dark,
                  label: 'Collection',
                  value: collection,
                ),
                const SizedBox(height: 16),
                if (description != null &&
                    description.toString().isNotEmpty) ...[
                  Text(
                    'Description',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : kBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.toString(),
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      height: 1.5,
                      color: dark
                          ? Colors.white.withOpacity(0.9)
                          : Colors.black.withOpacity(0.9),
                    ),
                  ),
                ],
                // Optional tags section if present.
                const SizedBox(height: 16),
                if (product['tags'] is List &&
                    (product['tags'] as List).isNotEmpty) ...[
                  Text(
                    'Tags',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : kBlack,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (product['tags'] as List)
                        .map((t) => Chip(
                              label: Text(
                                t.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: dark ? Colors.black : kOffWhite,
                              side: BorderSide(
                                color: dark ? kGold : kBlack.withOpacity(0.2),
                                width: 0.8,
                              ),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                // Bottom actions: ecommerce vs contact, same logic as card.
                if (isEcommerceWeb && kIsWeb)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleAddToCart(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            'Add to Cart',
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 11 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              _handleAddToCart(context, buyNow: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: kBlack,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                          child: Text(
                            'Buy Now',
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 11 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isContactLoading) return;

                            if (sellerPhone == null || sellerPhone!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Phone number not available'),
                                ),
                              );
                              return;
                            }

                            String phone = sellerPhone!.trim();
                            if (!phone.startsWith('+')) {
                              phone = '+91$phone';
                            }

                            final Uri telUri = Uri.parse('tel:$phone');
                            await launchUrl(telUri,
                                mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(Icons.call,
                              size: 18, color: Colors.white),
                          label: Text(
                            'Call Now',
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 11 : 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBlack,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isContactLoading) return;

                            if (sellerWhatsapp == null ||
                                sellerWhatsapp!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('WhatsApp not available'),
                                ),
                              );
                              return;
                            }

                            String phone = sellerWhatsapp!.trim();
                            if (!phone.startsWith('+')) {
                              phone = '+91$phone';
                            }

                            final message = Uri.encodeComponent(
                                "Hello, I'm interested in $name");
                            final Uri waUri =
                                Uri.parse('https://wa.me/$phone?text=$message');
                            await launchUrl(waUri,
                                mode: LaunchMode.externalApplication);
                          },
                          icon: const Icon(
                            FontAwesomeIcons.whatsapp,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            'WhatsApp',
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 11 : 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildDetailSpecRow(
    BuildContext context, {
    required bool dark,
    required String label,
    required dynamic value,
    String postfix = '',
  }) {
    final textRaw = (value ?? '').toString();
    if (textRaw.isEmpty) return const SizedBox.shrink();
    final text = '$textRaw$postfix';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: dark ? Colors.white70 : kBlack.withOpacity(0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.lato(
                fontSize: 13,
                color: dark ? Colors.white : kBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
