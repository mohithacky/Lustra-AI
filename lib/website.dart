import 'package:flutter/material.dart';
import 'package:lustra_ai/firebase_options.dart';
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
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
@@ -32,20 +26,23 @@ class WebSite extends StatefulWidget {
}

class _WebSiteState extends State<WebSite> {


  @override
  Widget build(BuildContext context) {
    // Read ?shopId=xxxx from URL
    final uri = Uri.base; // Works on all platforms
    final shopId = uri.queryParameters['shopId'];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Add a theme to ensure consistent styling
        primaryColor: const Color(0xFFC5A572),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFC5A572),
        ),
      ),
      home: const CollectionsScreen(),
      home: CollectionsScreen(
        shopId: shopId, // <-- Pass the shop ID here
      ),
    );
  }
}
