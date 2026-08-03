import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// One of the 5 main tabs — icon + label only, shared by [AppBottomNav]
/// (mobile) and `AppNavSidebar` (desktop) so both read from a single
/// source instead of duplicating the tab list.
class NavTabData {
  const NavTabData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

const List<NavTabData> kMainNavTabs = [
  NavTabData(icon: Symbols.home_rounded, label: 'Home'),
  NavTabData(icon: Symbols.explore_rounded, label: 'Explore'),
  NavTabData(icon: Symbols.auto_awesome_rounded, label: 'Planner'),
  NavTabData(icon: Symbols.bookmark_rounded, label: 'Saved'),
  NavTabData(icon: Symbols.person_rounded, label: 'Profile'),
];
