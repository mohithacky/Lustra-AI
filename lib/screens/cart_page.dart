import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lustra_ai/screens/theme_selection_screen.dart';

class CartPage extends StatelessWidget {
  final String shopId;
  final String websiteCustomerId;
  final String? shopName;
  final String? logoUrl;
  final WebsiteTheme? websiteTheme;

  const CartPage({
    Key? key,
    required this.shopId,
    required this.websiteCustomerId,
    this.shopName,
    this.logoUrl,
    this.websiteTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDark = websiteTheme == WebsiteTheme.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (logoUrl != null && logoUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(logoUrl!),
                  backgroundColor: Colors.transparent,
                ),
              ),
            Flexible(
              child: AutoSizeText(
                shopName ?? 'Your Cart',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                minFontSize: 16,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(shopId)
            .collection('users')
            .doc(websiteCustomerId)
            .collection('cart')
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong loading your cart',
                style: GoogleFonts.lato(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Your cart is empty',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = data['name']?.toString() ?? 'Product';
              final price = data['price'];
              final image = data['image']?.toString();
              final quantity = data['quantity'] ?? 1;

              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.image_outlined, size: 32),
                  title: Text(
                    name,
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '₹${price.toString()} · Qty $quantity',
                    style: GoogleFonts.lato(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
