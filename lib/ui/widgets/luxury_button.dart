import 'package:flutter/material.dart';
import '../theme/luxury_theme.dart';

class LuxuryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  const LuxuryButton({
    Key? key,
    required this.text,
    this.onTap,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: LuxuryTheme.goldButtonStyle,
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, color: Colors.white, size: 18),
                  if (icon != null) const SizedBox(width: 8),
                  Text(text),
                ],
              ),
      ),
    );
  }
}
