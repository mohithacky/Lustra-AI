import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'add_product_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';

// Import shared color constants
import 'package:lustra_ai/screens/theme_selection_screen.dart';

const Color kOffWhite = Color(0xFFF8F7F4);
const Color kGold = Color(0xFFC5A572);
const Color kBlack = Color(0xFF121212);
const Color kCream = Color(0xFFF8EDD1);

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

  @override
  void initState() {
    super.initState();
    _products = widget.products;
  }

  Future<void> _refetchProducts() async {
    final updatedProducts =
        await _firestoreService.getProductsForCategory(widget.categoryName);
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
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    final bool isDarkMode = widget.websiteTheme == WebsiteTheme.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : kOffWhite,
      endDrawer: isDesktop ? null : _buildMobileDrawer(),
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? Colors.black : kOffWhite.withOpacity(0.85),
        elevation: 2,
        shadowColor: kBlack.withOpacity(0.1),
        title: Row(
          children: [
            if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(widget.logoUrl!),
                  radius: 20,
                ),
              ),
            Text(
              widget.shopName ?? 'Lustra',
              style: GoogleFonts.lora(
                fontSize: isMobile ? 16 : 24,
                fontWeight: FontWeight.w700,
                color: isDarkMode ? Colors.white : kGold,
              ),
            ),
          ],
        ),
        actions: isDesktop
            ? null
            : [
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.menu_rounded,
                        color: isDarkMode ? Colors.white : kBlack, size: 30),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    tooltip: 'Menu',
                  ),
                ),
              ],
        bottom: isDesktop ? _buildDesktopNavBar(context) : null,
      ),
      body: Column(
        children: [
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
                          categoryName: widget.categoryName,
                          userId: widget.userId),
                    ),
                  );
                  // Refetch products when returning from the add product screen
                  _refetchProducts();
                },
                icon:
                    const Icon(Icons.add_circle_outline_rounded, color: kBlack),
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
                // Category heading
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                    child: Text(
                      widget.categoryName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : kBlack,
                      ),
                    ),
                  ),
                ),

                // Category filter tags
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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

                // Products grid
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: isMobile ? 2 : 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childCount: _products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: _products[index]);
                    },
                  ),
                ),

                // Bottom padding
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
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  // Desktop navigation bar at the bottom of AppBar
  PreferredSize _buildDesktopNavBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Row(
          children: [
            // Center Part: Search Field
            Flexible(
              flex: 2,
              child: _buildSearchField(),
            ),

            // Right Part: Menu Items and Icons
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

  // Mobile drawer
  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: kOffWhite,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            _buildDrawerItem('Home'),
            _buildDrawerItem('Collections'),
            _buildDrawerItem('Earrings'),
            _buildDrawerItem('Rings'),
            const Divider(height: 40),
            _buildDrawerItem('Profile'),
            _buildDrawerItem('Cart'),
          ],
        ),
      ),
    );
  }

  // Helper methods for navigation
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

  const ProductCard({
    Key? key,
    required this.product,
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
        color: Colors.white,
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
          // Product image with wishlist icon and badge
          Stack(
            children: [
              // Product image
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

              // Wishlist heart icon
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

              // Bestseller or Trending badge
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

          // Product details
          Container(
            decoration: BoxDecoration(
                color: kGold.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16))),
            padding: EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                AutoSizeText(
                  widget.product['name'],
                  style: GoogleFonts.playfairDisplay(
                    fontSize: isMobile ? 14 : 18,
                    fontWeight: FontWeight.w500,
                    color: kBlack,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Price and discount
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(
                      '₹${widget.product['price'].toString()}',
                      style: GoogleFonts.lato(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: kBlack,
                      ),
                    ),
                    if (widget.product.containsKey('weight') &&
                        widget.product['weight'].isNotEmpty)
                      Text(
                        '${widget.product['weight'].toString()}g',
                        style: GoogleFonts.lato(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                      ),
                    if (hasDiscount)
                      Text(
                        '₹${widget.product['originalPrice'].toString()}',
                        style: GoogleFonts.lato(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),

                // Discount tag
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
                          Icon(
                            Icons.discount_outlined,
                            size: isMobile ? 12 : 14,
                            color: kGold,
                          ),
                          Text(
                            widget.product['discount'].toString(),
                            style: GoogleFonts.lato(
                              fontSize: isMobile ? 10 : 12,
                              color: kBlack.withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // View Similar button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kGold,
                      side: const BorderSide(color: kGold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'View Similar',
                      style: GoogleFonts.lato(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
