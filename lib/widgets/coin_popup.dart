import 'package:flutter/material.dart';

class CoinPopup extends StatefulWidget {
  const CoinPopup({Key? key}) : super(key: key);

  @override
  _CoinPopupState createState() => _CoinPopupState();
}

class _CoinPopupState extends State<CoinPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A), // _darkGrey
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          title: const Text(
            'Congratulations!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFE3C887)), // _softGold
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'You\'ve received',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '100 Free Coins',
                style: TextStyle(
                  color: const Color(0xFFE3C887), // _softGold
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Awesome!', style: TextStyle(color: Color(0xFFE3C887))), // _softGold
            ),
          ],
        ),
      ),
    );
  }
}
