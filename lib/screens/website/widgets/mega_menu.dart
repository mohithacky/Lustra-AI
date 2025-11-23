import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lustra_ai/screens/theme_selection_screen.dart';

class MegaMenu extends StatelessWidget {
  final String nav;
  final String? userId;
  final WebsiteTheme websiteTheme;
  final Function(String) onItemTap;

  const MegaMenu({
    super.key,
    required this.nav,
    required this.userId,
    required this.websiteTheme,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    final isDark = websiteTheme == WebsiteTheme.dark;
    final bgColor =
        isDark ? const Color(0xFF121212) : Colors.white; // matte charcoal

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 40),
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black26,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          final collections =
              (data['collections'] ?? {}) as Map<String, dynamic>;
          final categories = (data['categories'] ?? {}) as Map<String, dynamic>;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: snap.hasData ? 1 : 0,
            child: SizedBox(
              height: 270,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left — Collection preview cards
                  Expanded(
                    flex: 3,
                    child: GridView.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: collections.entries.map((entry) {
                        return _CollectionCard(
                          title: entry.key,
                          imageUrl: entry.value,
                          dark: isDark,
                          onTap: () => onItemTap(entry.key),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(width: 40),

                  // Right — Category Chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Categories",
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            )),
                        const SizedBox(height: 12),
                        Wrap(
                          runSpacing: 10,
                          spacing: 10,
                          children: categories.keys.map((c) {
                            return GestureDetector(
                              onTap: () => onItemTap(c),
                              child: Chip(
                                backgroundColor: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[200],
                                shape: StadiumBorder(
                                  side: BorderSide(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black12),
                                ),
                                label: Text(
                                  c,
                                  style: GoogleFonts.lato(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollectionCard extends StatefulWidget {
  final String title;
  final String imageUrl;
  final bool dark;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.title,
    required this.imageUrl,
    required this.dark,
    required this.onTap,
  });

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: hover ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(widget.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity),
              ),
              Container(
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(.65),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  widget.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
