import 'package:flutter/material.dart';
import '../theme/luxury_theme.dart';

class LuxuryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool elevated;
  final GestureTapCallback? onTap;

  const LuxuryCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.elevated = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: LuxuryTheme.premiumCard(elevated: elevated),
      padding: padding,
      child: child,
    );

    return onTap != null
        ? InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: card,
          )
        : card;
  }
}
