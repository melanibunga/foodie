import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_text.dart';
import 'ui/sticky_bottom_bar.dart';

enum NavTab {
  home('/home', 'Home', LucideIcons.home),
  search('/search', 'Search', LucideIcons.search),
  add('/add', 'Add', LucideIcons.plus),
  plan('/meal-plan', 'Plan', LucideIcons.calendarDays),
  nearby('/nearby', 'Nearby', LucideIcons.mapPin);

  static const NavTab loc = nearby;

  final String route;
  final String label;
  final IconData icon;

  const NavTab(this.route, this.label, this.icon);
}

/// Floating bottom navigation bar (365 × 75 pada lebar 440) sesuai PRD §5.2, §14.4, §16.
/// - Floating overlay dengan bayangan halus
/// - 5 tab: Home · Search · Add · Plan · Nearby
/// - Item aktif = lingkaran amber 59 × 57 di dalam bar (berisi ikon + label warna onAccent)
class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  NavTab? get _activeTab {
    if (currentRoute.startsWith('/home')) return NavTab.home;
    if (currentRoute.startsWith('/search')) return NavTab.search;
    if (currentRoute.startsWith('/add')) return NavTab.add;
    if (currentRoute.startsWith('/meal-plan')) return NavTab.plan;
    if (currentRoute.startsWith('/nearby')) return NavTab.nearby;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottomMargin = bottomGap(context);
    final activeTab = _activeTab;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomMargin,
      child: Center(
        child: Container(
          width: 365.0,
          height: 75.0,
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          decoration: BoxDecoration(
            color: palette.navSurface,
            borderRadius: AppRadius.bottomNav,
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                offset: const Offset(0, 8),
                blurRadius: 24,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: NavTab.values.map((tab) {
              final isActive = tab == activeTab;
              return _buildNavItem(context, tab, isActive, palette);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    NavTab tab,
    bool isActive,
    AppPalette palette,
  ) {
    if (isActive) {
      // Item aktif: lingkaran amber 59 × 57
      return Semantics(
        label: '${tab.label} (aktif)',
        selected: true,
        button: true,
        child: GestureDetector(
          onTap: () {
            if (currentRoute != tab.route) {
              context.go(tab.route);
            }
          },
          child: Container(
            width: 59.0,
            height: 57.0,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tab.icon, color: palette.onAccent, size: 20.0),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: AppText.bottomNav.copyWith(
                    color: palette.onAccent,
                    fontSize: 10.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Item non-aktif
    final inactiveColor = palette.isDark
        ? palette.textStrong
        : palette.onAction;

    return Semantics(
      label: tab.label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (tab == NavTab.add) {
            context.push(tab.route);
          } else {
            context.go(tab.route);
          }
        },
        child: SizedBox(
          width: 56.0,
          height: 57.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, color: inactiveColor, size: 20.0),
              const SizedBox(height: 2),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppText.bottomNav.copyWith(
                  color: inactiveColor,
                  fontSize: 10.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
