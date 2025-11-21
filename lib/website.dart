import 'package:flutter/material.dart';
import 'package:lustra_ai/firebase_options.dart';
import 'package:lustra_ai/screens/collections_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:lustra_ai/services/firestore_service.dart';

Future<void> initializeFirebaseWeb() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseWeb();
  runApp(const WebSite());
}

class WebSite extends StatefulWidget {
  const WebSite({super.key});

  @override
  State<WebSite> createState() => _WebSiteState();
}

class _WebSiteState extends State<WebSite> {
  @override
  Widget build(BuildContext context) {
    // Get full host: e.g., "xyz.lustrai.in"
    final host = Uri.base.host;

    String? shopDomain;

    // Split by dot
    final parts = host.split('.');

    // Check if domain is a subdomain
    // Example: [xyz, lustrai, in]
    if (parts.length >= 3) {
      // Only take the FIRST part as shop ID
      final potentialSubdomain = parts.first;

      print("The potential sub domain is : $potentialSubdomain ");
      // Prevent treating the main domain as shop
      if (potentialSubdomain != "www" && potentialSubdomain != "lustrai") {
        shopDomain = potentialSubdomain;
      }
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFC5A572),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFC5A572),
        ),
      ),
      home: shopDomain == null
          ? const Scaffold(
              body: Center(
                child: Text('Shop not found'),
              ),
            )
          : FutureBuilder<String?>(
              future: FirestoreService().getUserIdByShopDomain(shopDomain),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final userId = snapshot.data;

                if (userId == null) {
                  return const Scaffold(
                    body: Center(
                      child: Text('Shop not found'),
                    ),
                  );
                }

                return CollectionsScreen(
                  shopId: userId,
                );
              },
            ),
    );
  }
}
