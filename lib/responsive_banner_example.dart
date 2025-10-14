import 'package:flutter/material.dart';

void main() {
  runApp(const ResponsiveBannerApp());
}

class ResponsiveBannerApp extends StatelessWidget {
  const ResponsiveBannerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Responsive Banner Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ResponsiveBannerDemo(),
    );
  }
}

class ResponsiveBannerDemo extends StatelessWidget {
  const ResponsiveBannerDemo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Responsive Banner Example'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with fixed aspect ratio
          const AspectRatio(
            aspectRatio: 16 / 9, // Standard 16:9 aspect ratio
            child: BannerWidget(),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Screen Width: ${MediaQuery.of(context).size.width.toStringAsFixed(2)}px',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Screen Height: ${MediaQuery.of(context).size.height.toStringAsFixed(2)}px',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'The banner above maintains a 16:9 aspect ratio regardless of screen size. This ensures the banner looks consistent across all devices.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Content below banner',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class BannerWidget extends StatelessWidget {
  const BannerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if we're on a mobile device
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://via.placeholder.com/1600x900/F8F7F4/121212?text=Banner+Image'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.black.withOpacity(0.3),
              Colors.transparent
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: const [0.0, 0.5, 0.9],
          ),
        ),
        child: Padding(
          // Use proportional padding that scales with screen size
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width * 0.05, // 5% of screen width
            vertical: MediaQuery.of(context).size.height * 0.05,  // 5% of screen height
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                const Text(
                  'Special Collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A572),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40, 
                    vertical: 15
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Shop Now',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
