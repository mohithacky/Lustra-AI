import 'package:flutter/material.dart';

class CircularCategoryCarousel extends StatefulWidget {
  final List<Map<String, String>> categories;
  final Function(String) onCategorySelected;
  final String? selectedItem;

  const CircularCategoryCarousel({
    Key? key,
    required this.categories,
    required this.onCategorySelected,
    this.selectedItem,
  }) : super(key: key);

  @override
  State<CircularCategoryCarousel> createState() =>
      _CircularCategoryCarouselState();
}

class _CircularCategoryCarouselState extends State<CircularCategoryCarousel> {
  bool showAll = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleShowAll() {
    setState(() => showAll = !showAll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (showAll) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0;
    const spacing = 12.0;
    const visibleItems = 4; // 3 items + All button

    final itemWidth =
        (screenWidth - horizontalPadding * 2 - spacing * (visibleItems - 1)) /
            visibleItems;

    final List<Map<String, String>> normalCategories = widget.categories
        .where((c) => c['name']!.toLowerCase() != 'all')
        .toList();
    final Map<String, String> allButton =
        widget.categories.firstWhere((c) => c['name']!.toLowerCase() == 'all');

    final List<Map<String, String>> itemsToShow = showAll
        ? [...normalCategories, allButton]
        : [...normalCategories.take(3), allButton];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: 150,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: itemsToShow.length,
        separatorBuilder: (_, __) => const SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final category = itemsToShow[index];
          final name = category['name']!;
          final isAllButton = name.toLowerCase() == 'all';
          final isSelected = widget.selectedItem == name;

          return GestureDetector(
            onTap: () {
              if (isAllButton) {
                _toggleShowAll();
              } else {
                widget.onCategorySelected(name);
              }
            },
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: itemWidth,
                  height: itemWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD700) // gold border
                          : Colors.transparent,
                      width: 2,
                    ),
                    image: isAllButton
                        ? null
                        : DecorationImage(
                            image: AssetImage(category['image']!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  alignment: Alignment.center,
                  child: isAllButton
                      ? Text(
                          "All",
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFFFD700) // gold if selected
                        : Colors.white, // white if not selected
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
