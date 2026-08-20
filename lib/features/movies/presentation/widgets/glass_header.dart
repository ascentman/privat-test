import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted header laid over the page content.
///
/// Deliberately not an [AppBar] with a blurred `flexibleSpace`: with a `bottom`
/// widget attached that arrangement only frosts part of the strip, leaving the
/// rows underneath sharp and readable. Here the filter wraps the whole header,
/// so what it covers is exactly what it blurs.
class GlassHeader extends StatelessWidget {
  const GlassHeader({required this.title, required this.field, super.key});

  final Widget title;
  final Widget field;

  /// Height below the status bar: the title row plus the field row.
  static const double contentHeight = 56 + 66;

  /// What a scrollable underneath must leave clear at its top.
  static double insetOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + contentHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.68),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.18),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: contentHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: DefaultTextStyle.merge(
                          // Nullable on purpose: a bare MaterialApp carries no
                          // appBarTheme.titleTextStyle, and forcing it threw.
                          style:
                              Theme.of(context).appBarTheme.titleTextStyle ??
                              Theme.of(context).textTheme.titleLarge,
                          child: title,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: field,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
