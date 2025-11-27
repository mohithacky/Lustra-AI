import 'package:flutter/material.dart';
import 'package:lustra_ai/firebase_options.dart';
import 'package:lustra_ai/screens/collections_screen.dart';
import 'package:lustra_ai/screens/try_on_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeFirebaseWeb() async {
  if (kIsWeb) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseWeb();

  runApp(const WebSite());
}

class WebSite extends StatefulWidget {
  const WebSite({Key? key}) : super(key: key);

  @override
  State<WebSite> createState() => _WebSiteState();
}

class _WebSiteState extends State<WebSite> {
  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final shopId = uri.queryParameters['shopId'];
    final productId = uri.queryParameters['productId'];
    final rawMode = uri.queryParameters['mode'];
    final mode = rawMode?.toLowerCase();

    final bool hasTryOnMode = mode != null && mode == 'tryon';
    final bool hasIds = shopId != null &&
        shopId.isNotEmpty &&
        productId != null &&
        productId.isNotEmpty;

    // Open TryOnScreen if:
    // - mode=tryon is explicitly set, OR
    // - there's a valid productId (shared try-on links)
    final bool shouldOpenTryOn = hasIds && (hasTryOnMode || mode == null);

    Widget home;
    if (shouldOpenTryOn) {
      home = TryOnScreen(shopId: shopId!, productId: productId!);
    } else {
      home = CollectionsScreen(shopId: shopId);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFC5A572),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFC5A572),
        ),
      ),
      home: home,
    );
  }
}
