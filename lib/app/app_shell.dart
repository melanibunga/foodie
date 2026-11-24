import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_shadows.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static double topChrome(BuildContext context) {
    return math.max(MediaQuery.paddingOf(context).top, 60.0);
  }

  static const double bottomNavPadding = 120.0;

  static const double maxAppWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > maxAppWidth) {
          return Container(
            color: palette.outerBg,
            alignment: Alignment.center,
            child: Container(
              width: maxAppWidth,
              height: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.bg,
                boxShadow: AppShadows.shellColumn,
              ),
              child: child,
            ),
          );
        }

        return Container(color: palette.bg, child: child);
      },
    );
  }
}
