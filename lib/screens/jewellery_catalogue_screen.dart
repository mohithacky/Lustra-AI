import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lustra_ai/constants/default_catalogue_data.dart';

class JewelleryCatalogueScreen extends StatefulWidget {
  const JewelleryCatalogueScreen({Key? key}) : super(key: key);

  @override
  State<JewelleryCatalogueScreen> createState() =>
      _JewelleryCatalogueScreenState();
}

class _JewelleryCatalogueScreenState extends State<JewelleryCatalogueScreen> {
  static const Color _softGold = Color(0xFFE3C887);
  static const Color _matteBlack = Color(0xFF121212);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  final TextEditingController _searchController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final List<String> _categories = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPersistedCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredCategories {
    final all = <String>[..._categories];
    if (_searchQuery.isEmpty) {
      return all;
    }
    return all.where((c) => c.toLowerCase().contains(_searchQuery)).toList();
  }

  Future<void> _loadPersistedCategories() async {
    try {
      final remote = await _firestoreService.getUserCatalogueCategories();
      if (!mounted) return;

      if (remote.isNotEmpty) {
        setState(() {
          _categories
            ..clear()
            ..addAll(remote);
        });
        return;
      }

      // If there are no catalogue categories yet (older users or very first
      // launch), seed them from the default website categories constant and
      // persist to Firestore so that subsequent loads use the same data.
      final seeded = kDefaultWebsiteCategories.keys.toList();
      setState(() {
        _categories
          ..clear()
          ..addAll(seeded);
      });
      await _firestoreService.saveUserCatalogueCategories(seeded);
    } catch (e) {
      // Non-fatal: fall back to local defaults based on the centralized
      // default website categories constant.
      // ignore: avoid_print
      print('Failed to load catalogue categories: $e');
      if (!mounted) return;
      setState(() {
        _categories
          ..clear()
          ..addAll(kDefaultWebsiteCategories.keys);
      });
    }
  }

  Future<void> _saveCategoriesToFirestore() async {
    try {
      await _firestoreService.saveUserCatalogueCategories(_categories);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not save categories. Please check your connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;

    return Scaffold(
      backgroundColor: _matteBlack,
      appBar: AppBar(
        backgroundColor: _darkGrey,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Jewellery Catalogue',
          style: TextStyle(
            color: _softGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSearchAndAddRow(),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final name = categories[index];
                  return _CategoryTile(
                    name: name,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => JewelleryCategoryDetailScreen(
                            categoryName: name,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndAddRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search categories',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white70, size: 20),
              filled: true,
              fillColor: _darkGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _softGold),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _softGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _showAddCategoryDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              'New',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _darkGrey,
          title: const Text(
            'Add Category',
            style: TextStyle(color: _softGold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter category name',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final lowerName = name.toLowerCase();
                  final exists =
                      _categories.any((c) => c.toLowerCase() == lowerName);
                  if (!exists) {
                    setState(() {
                      _categories.add(name);
                    });
                    await _saveCategoriesToFirestore();
                  }
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Add',
                style: TextStyle(color: _softGold),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _CategoryTile({Key? key, required this.name, required this.onTap})
      : super(key: key);

  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _darkGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _softGold,
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.circle,
              size: 32,
              color: _softGold,
            ),
            const SizedBox(height: 12),
            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JewelleryCategoryDetailScreen extends StatefulWidget {
  final String categoryName;

  const JewelleryCategoryDetailScreen({Key? key, required this.categoryName})
      : super(key: key);

  @override
  State<JewelleryCategoryDetailScreen> createState() =>
      _JewelleryCategoryDetailScreenState();
}

class _JewelleryCategoryDetailScreenState
    extends State<JewelleryCategoryDetailScreen> {
  static const Color _matteBlack = Color(0xFF121212);
  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  final FirestoreService _firestoreService = FirestoreService();

  late List<String> _subcategories;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subcategories = [];
    _loadPersistedSubcategories();
  }

  List<String> _getDefaultSubcategories(String category) {
    final name = category.toLowerCase();
    if (name == 'earrings') {
      return ['Studs', 'Hoops', 'Jhumkas', 'Drops', 'Daily wear'];
    } else if (name == 'chains') {
      return ['Light chains', 'Heavy chains', 'Daily wear', 'Kids'];
    } else if (name == 'rings') {
      return ['Solitaire', 'Bands', 'Couple rings', 'Cocktail'];
    } else if (name == 'bracelets') {
      return ['Tennis', 'Kada', 'Charm', 'Daily wear'];
    } else if (name == 'pendants') {
      return ['Solitaire', 'Initials', 'Heart', 'Religious'];
    } else if (name == 'nose pins') {
      return ['Simple', 'Stone', 'Bridal', 'Daily wear'];
    } else if (name == 'bangles') {
      return ['Gold bangles', 'Designer bangles', 'Daily wear', 'Bridal'];
    } else if (name == 'anklets') {
      return ['Simple', 'Fancy', 'Bridal', 'Kids'];
    }
    return ['Daily wear', 'Occasion wear'];
  }

  Future<void> _loadPersistedSubcategories() async {
    try {
      final remote = await _firestoreService
          .getUserCatalogueSubcategories(widget.categoryName);
      if (!mounted) return;

      if (remote.isNotEmpty) {
        setState(() {
          _subcategories = List<String>.from(remote);
        });
      } else {
        // No saved subcategories yet for this category. Prefer the
        // centralized defaults map if available; otherwise fall back to the
        // previous hardcoded defaults helper.
        final defaultsFromMap =
            kDefaultCatalogueSubcategories[widget.categoryName];
        final defaults =
            defaultsFromMap ?? _getDefaultSubcategories(widget.categoryName);

        setState(() {
          _subcategories = List<String>.from(defaults);
        });

        // Persist these defaults so future loads can rely solely on
        // Firestore data.
        await _firestoreService.saveUserCatalogueSubcategories(
            widget.categoryName, _subcategories);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load subcategories: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSubcategories() async {
    try {
      await _firestoreService.saveUserCatalogueSubcategories(
          widget.categoryName, _subcategories);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not save subcategories. Please check your connection.'),
        ),
      );
    }
  }

  Future<void> _showAddSubcategoryDialog() async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _darkGrey,
          title: const Text(
            'Add Subcategory',
            style: TextStyle(color: _softGold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Enter subcategory name',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final lowerName = name.toLowerCase();
                  final exists =
                      _subcategories.any((s) => s.toLowerCase() == lowerName);
                  if (!exists) {
                    setState(() {
                      _subcategories.add(name);
                    });
                    await _saveSubcategories();
                  }
                }
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text(
                'Add',
                style: TextStyle(color: _softGold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _matteBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subcategories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddSubcategoryDialog,
                  icon: const Icon(Icons.add, color: _softGold, size: 18),
                  label: const Text(
                    'New',
                    style: TextStyle(color: _softGold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_subcategories.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No subcategories yet. Add one to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  itemCount: _subcategories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final name = _subcategories[index];
                    return _SubcategoryTile(
                      name: name,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SubcategoryProductsScreen(
                              categoryName: widget.categoryName,
                              subcategoryName: name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _SubcategoryTile({Key? key, required this.name, required this.onTap})
      : super(key: key);

  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _darkGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _softGold,
            width: 1.2,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SubcategoryProductsScreen extends StatefulWidget {
  final String categoryName;
  final String subcategoryName;

  const SubcategoryProductsScreen({
    Key? key,
    required this.categoryName,
    required this.subcategoryName,
  }) : super(key: key);

  @override
  State<SubcategoryProductsScreen> createState() =>
      _SubcategoryProductsScreenState();
}

class _SubcategoryProductsScreenState extends State<SubcategoryProductsScreen> {
  static const Color _matteBlack = Color(0xFF121212);
  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final items =
          await _firestoreService.getProductsForCategoryAndSubcategory(
        widget.categoryName,
        widget.subcategoryName,
      );
      if (!mounted) return;
      setState(() {
        _products = items;
        _isLoading = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSubcategoryProductScreen(
          categoryName: widget.categoryName,
          subcategoryName: widget.subcategoryName,
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _isLoading = true;
      });
      await _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _matteBlack,
      appBar: AppBar(
        backgroundColor: _darkGrey,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.subcategoryName,
          style: const TextStyle(
            color: _softGold,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _softGold),
            onPressed: _openAddProduct,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _products.isEmpty
                ? const Center(
                    child: Text(
                      'No products yet. Add one to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : GridView.builder(
                    itemCount: _products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final name = (product['name'] ?? '') as String;

                      // Prefer explicit imageUrl (we save this as the first image),
                      // then fall back to the images list and legacy fields.
                      String imageUrl = '';
                      final primary = product['imageUrl'];
                      if (primary != null && primary.toString().isNotEmpty) {
                        imageUrl = primary.toString();
                      } else {
                        final images = product['images'];
                        if (images is List && images.isNotEmpty) {
                          final first = images.first;
                          if (first is String && first.isNotEmpty) {
                            imageUrl = first;
                          }
                        }
                        if (imageUrl.isEmpty && product['imagePath'] != null) {
                          imageUrl = product['imagePath'].toString();
                        }
                      }

                      return _ProductCard(
                        product: product,
                        name: name,
                        imageUrl: imageUrl,
                        onChanged: () async {
                          setState(() {
                            _isLoading = true;
                          });
                          await _loadProducts();
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String name;
  final String imageUrl;
  final Future<void> Function()? onChanged;

  const _ProductCard({
    Key? key,
    required this.product,
    required this.name,
    required this.imageUrl,
    this.onChanged,
  }) : super(key: key);

  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
        if (result == true && onChanged != null) {
          await onChanged!();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: _darkGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _softGold,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(
                            Icons.photo,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({Key? key, required this.product})
      : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const Color _matteBlack = Color(0xFF121212);
  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  late final List<String> _images;
  late final List<String> _videos;
  int _currentPage = 0;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _images = (product['images'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    _videos = (product['videos'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final name = (product['name'] ?? '') as String;
    final stock = (product['stock'] ?? '').toString();
    final description = (product['description'] ?? '').toString();

    final mediaCount = _images.length + _videos.length;

    return Scaffold(
      backgroundColor: _matteBlack,
      appBar: AppBar(
        backgroundColor: _darkGrey,
        elevation: 0,
        title: Text(
          name.isEmpty ? 'Product' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _softGold, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: _softGold),
            onPressed: _onEditPressed,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: _softGold),
            onPressed: _onDeletePressed,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mediaCount > 0)
              SizedBox(
                height: 260,
                child: PageView.builder(
                  itemCount: mediaCount,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final isImage = index < _images.length;
                    final url = isImage
                        ? _images[index]
                        : _videos[index - _images.length];

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          if (isImage)
                            Image.network(
                              url,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          else
                            _AutoPlayVideoPage(
                              url: url,
                              isActive: _currentPage == index,
                            ),
                          if (!isImage)
                            const Positioned(
                              right: 12,
                              bottom: 12,
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: _darkGrey,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _softGold, width: 1.2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.photo,
                    color: Colors.white24,
                    size: 40,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (stock.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                stock,
                style: const TextStyle(
                  color: _softGold,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildSpecRow('Category', product['category']),
            _buildSpecRow('Subcategory', product['subcategory']),
            _buildSpecRow('Karat', product['karat']),
            _buildSpecRow('Material', product['material']),
            _buildSpecRow('Weight', product['weight']),
            _buildSpecRow('Length', product['length']),
            _buildSpecRow('Making charges', product['making_charges']),
            _buildSpecRow('Stone', product['stone']),
            _buildSpecRow('SKU', product['sku']),
            const SizedBox(height: 16),
            if (description.isNotEmpty) ...[
              const Text(
                'Description',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (product['tags'] is List &&
                (product['tags'] as List).isNotEmpty) ...[
              const Text(
                'Tags',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
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
                          backgroundColor: _darkGrey,
                          side: const BorderSide(color: _softGold, width: 0.8),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _softGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _onAddToWebsitePressed,
                child: const Text(
                  'Add to Website',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSpecRow(String label, dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onAddToWebsitePressed() async {
    final product = widget.product;
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to add products to website.'),
        ),
      );
      return;
    }

    Map<String, String> collections = {};
    try {
      collections = await _firestoreService.getCollections(userId: user.uid);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load collections for Add to Website: $e');
    }

    if (!mounted) return;

    String? selectedCollection =
        (product['collection'] ?? '').toString().isNotEmpty
            ? (product['collection'] ?? '').toString()
            : null;
    bool isBestseller = (product['isBestseller'] ?? false) as bool;
    bool isTrending = (product['isTrending'] ?? false) as bool;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: _darkGrey,
                  title: const Text(
                    'Add to Website',
                    style: TextStyle(color: _softGold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedCollection,
                        items: collections.keys
                            .map(
                              (name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCollection = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Collection',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                        dropdownColor: _darkGrey,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        title: const Text(
                          'Bestseller',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: isBestseller,
                        onChanged: (value) {
                          setState(() {
                            isBestseller = value;
                          });
                        },
                        activeColor: _softGold,
                      ),
                      SwitchListTile.adaptive(
                        title: const Text(
                          'Trending',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: isTrending,
                        onChanged: (value) {
                          setState(() {
                            isTrending = value;
                          });
                        },
                        activeColor: _softGold,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (selectedCollection == null ||
                            selectedCollection!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a collection.'),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                      child: const Text(
                        'Add',
                        style: TextStyle(color: _softGold),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (!confirmed || selectedCollection == null) {
      return;
    }

    try {
      await _firestoreService.updateProduct(productId, {
        'collection': selectedCollection,
        'isBestseller': isBestseller,
        'isTrending': isTrending,
        'showOnWebsite': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product added to website products.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to website: $e')),
      );
    }
  }

  Future<void> _onEditPressed() async {
    final product = widget.product;
    final category = (product['category'] ?? '').toString();
    final subcategory = (product['subcategory'] ?? '').toString();
    final productId = (product['id'] ?? '').toString();

    if (category.isEmpty || subcategory.isEmpty || productId.isEmpty) {
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddSubcategoryProductScreen(
          categoryName: category,
          subcategoryName: subcategory,
          existingProduct: product,
          productId: productId,
        ),
      ),
    );

    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onDeletePressed() async {
    final product = widget.product;
    final productId = (product['id'] ?? '').toString();
    if (productId.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: _darkGrey,
              title: const Text(
                'Delete product',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Are you sure you want to delete this product?',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await _firestoreService.deleteProduct(productId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete product: $e')),
      );
    }
  }
}

class _AutoPlayVideoPage extends StatefulWidget {
  final String url;
  final bool isActive;

  const _AutoPlayVideoPage({
    Key? key,
    required this.url,
    required this.isActive,
  }) : super(key: key);

  @override
  State<_AutoPlayVideoPage> createState() => _AutoPlayVideoPageState();
}

class _AutoPlayVideoPageState extends State<_AutoPlayVideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _initialized = true;
        });
        if (widget.isActive) {
          _controller.play();
        }
      });
  }

  @override
  void didUpdateWidget(covariant _AutoPlayVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      if (_initialized && !_controller.value.isPlaying) {
        _controller.play();
      }
    } else {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || !_controller.value.isInitialized) {
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

class AddSubcategoryProductScreen extends StatefulWidget {
  final String categoryName;
  final String subcategoryName;
  final Map<String, dynamic>? existingProduct;
  final String? productId;

  const AddSubcategoryProductScreen({
    Key? key,
    required this.categoryName,
    required this.subcategoryName,
    this.existingProduct,
    this.productId,
  }) : super(key: key);

  @override
  State<AddSubcategoryProductScreen> createState() =>
      _AddSubcategoryProductScreenState();
}

class _AddSubcategoryProductScreenState
    extends State<AddSubcategoryProductScreen> {
  static const Color _matteBlack = Color(0xFF121212);
  static const Color _softGold = Color(0xFFE3C887);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _karatController = TextEditingController();
  final _materialController = TextEditingController();
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _makingChargesController = TextEditingController();
  final _stoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _stockController = TextEditingController();
  final _tagsController = TextEditingController();

  final List<String> _existingImageUrls = [];
  final List<String> _existingVideoUrls = [];
  final List<File> _imageFiles = [];
  final List<File> _videoFiles = [];
  bool _isSaving = false;

  final FirestoreService _firestoreService = FirestoreService();

  bool get _isEditing =>
      widget.productId != null && widget.productId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProduct;
    if (existing != null) {
      _nameController.text = (existing['name'] ?? '').toString();
      _karatController.text = (existing['karat'] ?? '').toString();
      _materialController.text = (existing['material'] ?? '').toString();
      _weightController.text = (existing['weight'] ?? '').toString();
      _lengthController.text = (existing['length'] ?? '').toString();
      _makingChargesController.text =
          (existing['making_charges'] ?? '').toString();
      _stoneController.text = (existing['stone'] ?? '').toString();
      _descriptionController.text = (existing['description'] ?? '').toString();
      _skuController.text = (existing['sku'] ?? '').toString();
      _stockController.text = (existing['stock'] ?? '').toString();

      if (existing['tags'] is List) {
        _tagsController.text =
            (existing['tags'] as List).map((e) => e.toString()).join(', ');
      } else if (existing['tags'] != null) {
        _tagsController.text = existing['tags'].toString();
      }

      final images = existing['images'];
      if (images is List) {
        _existingImageUrls
            .addAll(images.map((e) => e.toString()).where((e) => e.isNotEmpty));
      }
      final videos = existing['videos'];
      if (videos is List) {
        _existingVideoUrls
            .addAll(videos.map((e) => e.toString()).where((e) => e.isNotEmpty));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _karatController.dispose();
    _materialController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _makingChargesController.dispose();
    _stoneController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _stockController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'heic',
        'heif',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
      ],
    );

    if (result == null) return;

    setState(() {
      for (final file in result.files) {
        final path = file.path;
        if (path == null) continue;

        final ext = (file.extension ?? '').toLowerCase();
        const imageExts = {
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
          'heif',
        };
        const videoExts = {
          'mp4',
          'mov',
          'avi',
          'mkv',
          'webm',
        };

        if (imageExts.contains(ext)) {
          _imageFiles.add(File(path));
        } else if (videoExts.contains(ext)) {
          _videoFiles.add(File(path));
        }
      }
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final List<String> imageUrls = List<String>.from(_existingImageUrls);
      for (final file in _imageFiles) {
        final url = await _firestoreService.uploadProductImage(
          file,
          _nameController.text,
        );
        imageUrls.add(url);
      }

      final List<String> videoUrls = List<String>.from(_existingVideoUrls);
      for (final file in _videoFiles) {
        final url = await _firestoreService.uploadProductImage(
          file,
          _nameController.text,
        );
        videoUrls.add(url);
      }

      final tags = _tagsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final baseData = {
        'name': _nameController.text.trim(),
        'category': widget.categoryName,
        'subcategory': widget.subcategoryName,
        'karat': _karatController.text.trim(),
        'material': _materialController.text.trim(),
        'weight': _weightController.text.trim(),
        'length': _lengthController.text.trim(),
        'making_charges': _makingChargesController.text.trim(),
        'stone': _stoneController.text.trim(),
        'images': imageUrls,
        'videos': videoUrls,
        'description': _descriptionController.text.trim(),
        'sku': _skuController.text.trim(),
        'stock': _stockController.text.trim(),
        'tags': tags,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
      };

      if (_isEditing && widget.productId != null) {
        await _firestoreService.updateProduct(
          widget.productId!,
          {
            ...baseData,
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully!')),
        );
        Navigator.of(context).pop(true);
      } else {
        final productId =
            'PRD${DateTime.now().millisecondsSinceEpoch.toString()}';

        final productData = {
          'product_id': productId,
          ...baseData,
          'createdAt': DateTime.now().toIso8601String(),
        };

        await _firestoreService.addProduct(widget.categoryName, productData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add product: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _matteBlack,
      appBar: AppBar(
        backgroundColor: _darkGrey,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isEditing ? 'Edit Product' : 'Add Product',
          style: const TextStyle(
            color: _softGold,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _softGold,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.perm_media),
                  label: const Text('Add media'),
                  onPressed: _pickMedia,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: (_existingImageUrls.isEmpty &&
                        _existingVideoUrls.isEmpty &&
                        _imageFiles.isEmpty &&
                        _videoFiles.isEmpty)
                    ? const Center(
                        child: Text(
                          'No media selected',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingImageUrls.length +
                            _existingVideoUrls.length +
                            _imageFiles.length +
                            _videoFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final existingImageCount = _existingImageUrls.length;
                          final existingVideoCount = _existingVideoUrls.length;
                          final localImageCount = _imageFiles.length;

                          Widget child;
                          VoidCallback onRemove;

                          if (index < existingImageCount) {
                            final url = _existingImageUrls[index];
                            child = Image.network(
                              url,
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            );
                            onRemove = () {
                              setState(() {
                                _existingImageUrls.removeAt(index);
                              });
                            };
                          } else if (index <
                              existingImageCount + existingVideoCount) {
                            final videoIndex = index - existingImageCount;
                            child = Container(
                              width: 140,
                              height: 140,
                              color: Colors.grey[900],
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            );
                            onRemove = () {
                              setState(() {
                                _existingVideoUrls.removeAt(videoIndex);
                              });
                            };
                          } else if (index <
                              existingImageCount +
                                  existingVideoCount +
                                  localImageCount) {
                            final localImageIndex =
                                index - existingImageCount - existingVideoCount;
                            final file = _imageFiles[localImageIndex];
                            child = Image.file(
                              file,
                              width: 140,
                              height: 140,
                              fit: BoxFit.cover,
                            );
                            onRemove = () {
                              setState(() {
                                _imageFiles.removeAt(localImageIndex);
                              });
                            };
                          } else {
                            final localVideoIndex = index -
                                existingImageCount -
                                existingVideoCount -
                                localImageCount;
                            final file = _videoFiles[localVideoIndex];
                            child = Container(
                              width: 140,
                              height: 140,
                              color: Colors.grey[900],
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            );
                            onRemove = () {
                              setState(() {
                                _videoFiles.removeAt(localVideoIndex);
                              });
                            };
                          }

                          final isVideo = index >= existingImageCount &&
                                  index <
                                      existingImageCount + existingVideoCount ||
                              index >=
                                  existingImageCount +
                                      existingVideoCount +
                                      localImageCount;

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                child,
                                if (isVideo)
                                  const Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Icon(
                                      Icons.videocam,
                                      color: Colors.white,
                                    ),
                                  ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: GestureDetector(
                                    onTap: onRemove,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              _buildTextField(_nameController, 'Name', isRequired: true),
              const SizedBox(height: 12),
              _buildTextField(_karatController, 'Karat (e.g. 14K)'),
              const SizedBox(height: 12),
              _buildTextField(_materialController, 'Material (e.g. Gold)'),
              const SizedBox(height: 12),
              _buildTextField(_weightController, 'Weight (e.g. 8.4 g)'),
              const SizedBox(height: 12),
              _buildTextField(_lengthController, 'Length (e.g. 18 inch)'),
              const SizedBox(height: 12),
              _buildTextField(
                  _makingChargesController, 'Making charges (e.g. ₹350/g)'),
              const SizedBox(height: 12),
              _buildTextField(_stoneController, 'Stone (e.g. None)'),
              const SizedBox(height: 12),
              _buildTextField(_descriptionController, 'Description',
                  maxLines: 3),
              const SizedBox(height: 12),
              _buildTextField(_skuController, 'SKU'),
              const SizedBox(height: 12),
              _buildTextField(_stockController, 'Stock (e.g. Available)'),
              const SizedBox(height: 12),
              _buildTextField(
                  _tagsController, 'Tags (comma separated, e.g. daily wear)'),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _softGold,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _isSaving ? null : _saveProduct,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Product' : 'Save Product',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1, bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: _darkGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _softGold),
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}
