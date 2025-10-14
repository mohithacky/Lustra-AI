import 'package:flutter/material.dart';
import 'package:lustra_ai/screens/collections_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeFirebaseWeb() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyBlDsaqVXou8_m4Yn6HTir5LpYUUnJLAnE",
          authDomain: "lustra-ai.firebaseapp.com",
          projectId: "lustra-ai",
          storageBucket: "lustra-ai.firebasestorage.app",
          messagingSenderId: "853834753761",
          appId: "1:853834753761:web:62a116146555be2612f9a0",
          measurementId: "G-1WLF99RCPG"),
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
  String? shopName;
  String? logoUrl;
  String? userId;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    setState(() {
      shopName = uri.queryParameters['shopName'];
      logoUrl = uri.queryParameters['logoUrl'];
      userId = uri.queryParameters['userId'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Add a theme to ensure consistent styling
        primaryColor: const Color(0xFFC5A572),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFC5A572),
        ),
      ),
      home: CollectionsScreen(
          shopName: shopName, logoUrl: logoUrl, userId: userId),
    );
  }
}
