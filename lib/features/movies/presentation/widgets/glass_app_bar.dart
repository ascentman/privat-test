import 'dart:ui';

import 'package:flutter/material.dart';

/// A translucent app bar that blurs whatever scrolls beneath it.
///
/// The effect only exists if there is something behind the bar to blur, so
/// every screen using this must set `extendBodyBehindAppBar: true` and leave
/// its content free to pass underneath.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({this.title, this.bottom, super.key});

  final Widget? title;
  final PreferredSizeWidget? bottom;

  /// How tall the bar is, status bar aside — what a screen must leave clear at
  /// the top of its scrollable content.
  double get contentHeight =>
      kToolbarHeight + (bottom?.preferredSize.height ?? 0);

  @override
  Size get preferredSize => Size.fromHeight(contentHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      title: title,
      bottom: bottom,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              // Tinted heavily rather than clear: at a lighter alpha the rows
              // sliding underneath stayed legible enough to compete with the
              // title and the search field.
              color: scheme.surface.withValues(alpha: 0.82),
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
