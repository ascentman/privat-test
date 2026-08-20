import 'dart:ui';

import 'package:flutter/material.dart';

/// Round frosted button that floats over artwork — the only chrome the details
/// screen has, so the poster can run the full height of the viewport.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
