import 'package:flutter/material.dart';
import 'package:lustra_ai/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../ui/theme/luxury_theme.dart';
import '../../ui/widgets/luxury_button.dart';
import '../../ui/widgets/luxury_card.dart';
import '../../ui/widgets/section_header.dart';

class NewAdminDashboard extends StatefulWidget {
  const NewAdminDashboard({Key? key}) : super(key: key);

  @override
  State<NewAdminDashboard> createState() => _NewAdminDashboardState();
}

class _NewAdminDashboardState extends State<NewAdminDashboard> {
  String? userId;
  String? shopName;
  String? shopLogo;
  bool isLoading = true;

  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }
    userId = user.uid;

    final details = await _firestoreService.getUserDetailsFor(userId!);
    setState(() {
      shopName = details?['shopName'] ?? "My Brand";
      shopLogo = details?['logoUrl'];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: LuxuryTheme.offWhite,
      drawer: !isDesktop ? _buildDrawer() : null,
      floatingActionButton: !isDesktop ? _buildFab() : null,
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // -------------------- MOBILE UI --------------------

  Widget _buildMobileLayout() {
    return SafeArea(
      child: ListView(
        padding: LuxuryTheme.pagePadding,
        children: [
          _header(),
          const SizedBox(height: 20),
          _quickActions(),
          const SizedBox(height: 25),
          _websitePreviewCard(),
          const SizedBox(height: 25),
          _collectionsCard(),
          const SizedBox(height: 25),
          _categoriesCard(),
          const SizedBox(height: 25),
          _productsCard(),
          const SizedBox(height: 25),
          _footerCard(),
        ],
      ),
    );
  }

  // -------------------- DESKTOP UI (D2 Apple style) --------------------

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: LuxuryTheme.offWhite,
            child: ListView(
              padding: LuxuryTheme.pagePadding,
              children: [
                _header(),
                const SizedBox(height: 25),
                _quickActions(),
                const SizedBox(height: 25),
                _collectionsCard(),
                const SizedBox(height: 25),
                _categoriesCard(),
                const SizedBox(height: 25),
                _productsCard(),
                const SizedBox(height: 25),
                _footerCard(),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(22),
            child: _websitePreviewCard(),
          ),
        ),
      ],
    );
  }

  // -------------------- HEADER --------------------

  Widget _header() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: shopLogo != null ? NetworkImage(shopLogo!) : null,
          child: shopLogo == null
              ? const Icon(Icons.store, color: Colors.black)
              : null,
        ),
        const SizedBox(width: 14),
        Text(
          shopName ?? "Loading...",
          style: LuxuryTheme.textTheme.displayLarge!.copyWith(fontSize: 26),
        ),
      ],
    );
  }

  // -------------------- QUICK ACTIONS --------------------

  Widget _quickActions() {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: "Quick Actions"),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionChip("Add Collection", Icons.add_circle_outline, () {}),
              _actionChip("Add Category", Icons.category_outlined, () {}),
              _actionChip("Add Product", Icons.shopping_bag_outlined, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(String text, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: LuxuryTheme.gold, width: 1.3),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: LuxuryTheme.gold),
            const SizedBox(width: 6),
            Text(
              text,
              style: LuxuryTheme.textTheme.bodyLarge!.copyWith(
                color: LuxuryTheme.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- MODULE CARDS --------------------

  Widget _websitePreviewCard() {
    return LuxuryCard(
      padding: const EdgeInsets.all(0),
      elevated: true,
      child: Container(
        height: 380,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/preview_placeholder.jpg"),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _collectionsCard() {
    return LuxuryCard(
      child: const SectionHeader(title: "Collections"),
      onTap: () {
        // TODO: Navigate to collections management
      },
    );
  }

  Widget _categoriesCard() {
    return LuxuryCard(
      child: const SectionHeader(title: "Categories"),
      onTap: () {
        // TODO: Navigate to category management
      },
    );
  }

  Widget _productsCard() {
    return LuxuryCard(
      child: const SectionHeader(title: "Products"),
      onTap: () {
        // TODO: Navigate to products page
      },
    );
  }

  Widget _footerCard() {
    return LuxuryCard(
      child: const SectionHeader(title: "Footer & Links Settings"),
      onTap: () {
        // TODO: Navigate to footer edit page
      },
    );
  }

  // -------------------- MOBILE FAB ACTIONS --------------------

  Widget _buildFab() {
    return FloatingActionButton(
      backgroundColor: LuxuryTheme.gold,
      onPressed: () => _showFabMenu(),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: LuxuryTheme.offWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LuxuryButton(text: "Add Collection", onTap: () {}),
            const SizedBox(height: 10),
            LuxuryButton(text: "Add Category", onTap: () {}),
            const SizedBox(height: 10),
            LuxuryButton(text: "Add Product", onTap: () {}),
          ],
        ),
      ),
    );
  }

  // -------------------- MOBILE DRAWER --------------------

  Drawer _buildDrawer() {
    return Drawer(
      child: Container(
        padding: const EdgeInsets.all(18),
        color: LuxuryTheme.offWhite,
        child: ListView(
          children: [
            const SizedBox(height: 10),
            Text("Menu", style: LuxuryTheme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            _drawerItem("Dashboard", Icons.dashboard, () {}),
            _drawerItem("Collections", Icons.layers, () {}),
            _drawerItem("Categories", Icons.category, () {}),
            _drawerItem("Products", Icons.shopping_bag, () {}),
            _drawerItem("Footer Settings", Icons.web, () {}),
            _drawerItem("Logout", Icons.logout, () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: LuxuryTheme.black),
      title: Text(title, style: LuxuryTheme.textTheme.bodyLarge),
      onTap: onTap,
    );
  }
}
