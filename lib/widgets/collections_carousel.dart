import 'package:flutter/material.dart';

class CollectionsCarousel extends StatefulWidget {
  final Function(String) onCollectionSelected;
  final String? selectedCollection;
  final List<String> collections;

  const CollectionsCarousel({
    super.key,
    required this.onCollectionSelected,
    this.selectedCollection,
    required this.collections,
  });

  @override
  State<CollectionsCarousel> createState() => _CollectionsCarouselState();
}

class _CollectionsCarouselState extends State<CollectionsCarousel> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Set initial selected index based on selectedCollection
    if (widget.selectedCollection != null) {
      selectedIndex = widget.collections.indexOf(widget.selectedCollection!);
      if (selectedIndex == -1) selectedIndex = 0;
    }
  }

  @override
  void didUpdateWidget(CollectionsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update selected index if selectedCollection changes from parent
    if (widget.selectedCollection != oldWidget.selectedCollection) {
      if (widget.selectedCollection == null) {
        selectedIndex = 0;
      } else {
        selectedIndex = widget.collections.indexOf(widget.selectedCollection!);
        if (selectedIndex == -1) selectedIndex = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40, // this defines the exact visible height of the carousel
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: widget.collections.length,
        itemBuilder: (context, index) {
          final bool isSelected = selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedIndex = index;
                });
                widget.onCollectionSelected(widget.collections[index]);
              },
              child: Align(
                // ensures button height stays compact
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6, // smaller vertical padding for slim height
                  ),
                  constraints: const BoxConstraints(
                    minHeight: 10,
                    maxHeight: 111, // ensures fixed compact height
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1B1B1B)
                        : const Color(0xFF0E0E0E),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFB28C52)
                          : const Color(0xFF2A2A2A),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFB28C52).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      widget.collections[index],
                      style: TextStyle(
                        color:
                            isSelected ? const Color(0xFFB28C52) : Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
