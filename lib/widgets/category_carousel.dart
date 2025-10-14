import 'package:flutter/material.dart';
import 'package:lustra_ai/theme/app_theme.dart';

class CircularCategoryCarousel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final name = category['name']!;
        return _CarouselItem(
          name: name,
          imagePath: category['image']!,
          isSelected: name == selectedItem,
          onTap: () => onCategorySelected(name),
        );
      },
    );
  }
}

class _CarouselItem extends StatelessWidget {
  final String name;
  final String imagePath;
  final bool isSelected;
  final VoidCallback onTap;

  const _CarouselItem({
    required this.name,
    required this.imagePath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.accentColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: AssetImage(imagePath),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
