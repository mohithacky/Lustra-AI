import 'package:flutter/material.dart';
import 'package:lustra_ai/firebase_options.dart';
import 'package:lustra_ai/screens/collections_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
    // Read ?shopId=xxxx from URL
    final uri = Uri.base; // Works on all platforms
    final shopId = uri.queryParameters['shopId'];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFC5A572),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFC5A572),
        ),
      ),
      home: CollectionsScreen(
        shopId: shopId, // <-- Pass the shop ID here
      ),
    );
  }
}
