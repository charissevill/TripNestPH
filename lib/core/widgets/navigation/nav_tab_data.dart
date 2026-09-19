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

/// The 4th tab (index 3) for a `businessOwner` account — swapped in for
/// "Saved" (see [mainNavTabsFor]), since saved itineraries are a traveler
/// feature a business owner is far less likely to need front-and-center,
/// while their own listing (previously buried inside Profile) is the one
/// thing this role actually manages day to day.
const NavTabData _businessOwnerFourthTab = NavTabData(
  icon: Symbols.storefront_rounded,
  label: 'My Business',
);

/// [kMainNavTabs], with index 3 swapped to [_businessOwnerFourthTab] for a
/// `businessOwner` account — the branch at that index renders the matching
/// screen (see `MainShellScreen`'s 4th branch).
List<NavTabData> mainNavTabsFor({required bool isBusinessOwner}) {
  if (!isBusinessOwner) return kMainNavTabs;
  return [...kMainNavTabs.take(3), _businessOwnerFourthTab, kMainNavTabs.last];
}
