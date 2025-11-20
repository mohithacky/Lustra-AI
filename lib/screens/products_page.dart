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
import 'add_product_screen.dart';
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

  const ProductsPage({
    Key? key,
    required this.categoryName,
    required this.userId,
    required this.products,
    this.shopName,
    this.logoUrl,
    this.websiteTheme,
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

  @override
  @override
  void initState() {
    super.initState();
    _products = widget.products;
    _activeCategory = widget.categoryName;
    isDarkMode = widget.websiteTheme == WebsiteTheme.dark;
    _fetchSellerContactDetails();
    _loadDrawerData();
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

  Future<void> _refetchProducts() async {
    List<Map<String, dynamic>> updatedProducts;
    if (_activeCategory == 'All') {
      // When the global "All" category is selected, show all products
      updatedProducts =
          await _firestoreService.getAllProductsForUser(widget.userId);
    } else {
      updatedProducts = await _firestoreService.getProductsForCategoryfor(
          widget.userId, _activeCategory);
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
      updatedProducts = await _firestoreService.getProductsForCategoryfor(
          widget.userId, _activeCategory);
    } else {
      updatedProducts =
          await _firestoreService.getProductsForCategoryforWithFilter(
        widget.userId,
        _activeCategory,
        filter,
      );
    }

    setState(() {
      _products = updatedProducts;
    });
  }

  Future<void> _onCategorySelected(String category) async {
    setState(() {
      _activeCategory = category;
      _selectedFilter = 'All';
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
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (isAdminApp)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddProductScreen(
                            categoryName: _activeCategory,
                            userId: widget.userId),
                      ),
                    );
                    _refetchProducts();
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: kBlack),
                  label: Text(
                    'Add New Product',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w600,
                      color: kBlack,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGold.withOpacity(0.8),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                ),
              ),
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      _activeCategory,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : kBlack,
                      ),
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
                          if (!isAdminApp)
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
              onTap: () {},
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
  final String? sellerPhone;
  final String? sellerWhatsapp;
  final bool isContactLoading;

  const ProductCard({
    Key? key,
    required this.product,
    required this.shopId,
    this.sellerPhone,
    this.sellerWhatsapp,
    this.isContactLoading = false,
  }) : super(key: key);

  @override
  _ProductCardState createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isWishlisted = false;

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 600;
    final double imageHeight = isMobile ? 180 : 240;
    final bool hasDiscount = widget.product.containsKey('originalPrice');
    final bool isBestseller = widget.product['isBestseller'] ?? false;
    final bool isTrending = widget.product['isTrending'] ?? false;

    return Container(
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
                  widget.product['imagePath'] ?? widget.product['image'],
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: imageHeight,
                    color: kOffWhite,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported, color: kGold),
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
                      _isWishlisted ? Icons.favorite : Icons.favorite_border,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    if (widget.product.containsKey('weight') &&
                        widget.product['weight'].isNotEmpty)
                      Text(
                        '${widget.product['weight'].toString()}g',
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

                // Call and WhatsApp buttons
                // Call and WhatsApp buttons (Column layout)
                // Call & WhatsApp buttons (Firestore-powered)
                Column(
                  children: [
                    // CALL NOW BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (widget.isContactLoading) return;

                          if (widget.sellerPhone == null ||
                              widget.sellerPhone!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Phone number not available")),
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // WHATSAPP BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (widget.isContactLoading) return;

                          if (widget.sellerWhatsapp == null ||
                              widget.sellerWhatsapp!.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("WhatsApp not available")),
                            );
                            return;
                          }

                          String phone = widget.sellerWhatsapp!.trim();
                          if (!phone.startsWith('+')) phone = '+91$phone';

                          final message = Uri.encodeComponent(
                              "Hello, I'm interested in ${widget.product['name']}");
                          final Uri waUri =
                              Uri.parse("https://wa.me/$phone?text=$message");
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ADD TO CART BUTTON
                  ],
                ),

                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
