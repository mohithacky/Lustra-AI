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
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 16.0;
    const spacing = 12.0;

    return SizedBox(
      height: 80,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: widget.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final name = category['name']!;
          final isSelected = widget.selectedItem == name;

          return GestureDetector(
            onTap: () => widget.onCategorySelected(name),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFFD700)
                          : Colors.transparent,
                      width: 2,
                    ),
                    image: DecorationImage(
                      image: AssetImage(category['image']!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: (name != "Mangalsutra\nPendant" ||
                            name != "Long\nNecklace")
                        ? 13
                        : 10,
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
