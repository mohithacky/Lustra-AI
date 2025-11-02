import 'package:flutter/material.dart';

class AnimatedPopup extends StatefulWidget {
  final String message;
  final VoidCallback onActionPressed;

  const AnimatedPopup({
    Key? key,
    required this.message,
    required this.onActionPressed,
  }) : super(key: key);

  @override
  _AnimatedPopupState createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
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
    return ScaleTransition(
      scale: _animation,
      child: AlertDialog(
        title: const Text('Logo Not Found'),
        content: Text(widget.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: widget.onActionPressed,
            child: const Text('Add Logo'),
          ),
        ],
      ),
    );
  }
}
